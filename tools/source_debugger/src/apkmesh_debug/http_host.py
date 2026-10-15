from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import urljoin, urlsplit

import httpx

from .models import HostRequestError, ReplayMiss, ResponseData
from .policy import SourcePolicy
from .replay import RecordingStore, ReplayStore
from .trace import TraceRecorder


class HttpHost:
    def __init__(
        self,
        policy: SourcePolicy,
        trace: TraceRecorder,
        *,
        mode: str = "live",
        replay: ReplayStore | None = None,
        recording: RecordingStore | None = None,
        timeout: float = 15.0,
        download_dir: Path | None = None,
    ) -> None:
        self.policy = policy
        self.trace = trace
        self.mode = mode
        self.replay = replay
        self.recording = recording
        self.timeout = timeout
        self.download_dir = download_dir or Path("downloads")
        self.client = httpx.Client(follow_redirects=False, timeout=timeout)

    def request(
        self,
        url: str,
        headers: dict[str, str] | None = None,
        *,
        method: str = "GET",
        body: str | None = None,
    ) -> str:
        response = self.fetch(url, headers=headers, method=method, body=body)
        if response.status_code >= 400:
            raise HostRequestError(
                f"HTTP {response.status_code} for {url}", response=response
            )
        return self._decode(response)

    def fetch(
        self,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        capability: str = "network",
        method: str = "GET",
        body: str | None = None,
    ) -> ResponseData:
        normalized_method = method.strip().upper()
        if normalized_method not in {"GET", "POST"}:
            raise ValueError("only GET and POST requests are supported")
        current_url = url
        request_headers = dict(headers or {})
        request_body = body
        for redirect_count in range(7):
            self.policy.check(current_url, capability)
            self.trace.add(
                "http.request",
                method=normalized_method,
                url=current_url,
                headers=request_headers,
                redirect=redirect_count,
                mode=self.mode,
            )
            response = self._request_once(
                current_url,
                request_headers,
                normalized_method,
                request_body,
            )
            location = response.header("location")
            self.trace.add(
                "http.response",
                method=normalized_method,
                url=current_url,
                final_url=response.url,
                status=response.status_code,
                headers=response.headers,
                body=self.trace.body_preview(response.body),
                redirect=redirect_count,
            )
            if response.status_code not in {301, 302, 303, 307, 308}:
                return response
            if not location:
                raise HostRequestError(
                    f"redirect from {current_url} has no Location", response=response
                )
            next_url = urljoin(current_url, location)
            if response.status_code == 303 or (
                response.status_code in {301, 302} and normalized_method == "POST"
            ):
                normalized_method = "GET"
                request_body = None
                request_headers = {
                    key: value for key, value in request_headers.items()
                    if key.lower() not in {"content-type", "content-length", "transfer-encoding"}
                }
            previous = urlsplit(current_url)
            following = urlsplit(next_url)
            previous_origin = (previous.scheme, previous.hostname, previous.port or (443 if previous.scheme == "https" else 80))
            following_origin = (following.scheme, following.hostname, following.port or (443 if following.scheme == "https" else 80))
            if previous_origin != following_origin:
                request_headers = {
                    key: value for key, value in request_headers.items()
                    if key.lower() not in {"authorization", "proxy-authorization", "cookie", "host"}
                }
            current_url = next_url
        raise HostRequestError(f"too many redirects for {url}")

    def download(
        self,
        url: str,
        *,
        file_name: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> str:
        response = self.fetch(url, headers=headers, capability="download")
        if not 200 <= response.status_code < 300:
            raise HostRequestError(
                f"download returned HTTP {response.status_code} for {url}",
                response=response,
            )
        requested_name = file_name or Path(urlsplit(url).path).name or "download.apk"
        safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", requested_name)
        destination = self.download_dir / (safe_name or "download.apk")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(response.body)
        self.trace.add(
            "download.completed",
            url=url,
            path=destination,
            bytes=len(response.body),
        )
        return str(destination)

    def close(self) -> None:
        self.client.close()

    def _request_once(
        self,
        url: str,
        headers: dict[str, str],
        method: str,
        body: str | None,
    ) -> ResponseData:
        if self.mode == "replay":
            if self.replay is None:
                raise RuntimeError("replay mode requires a ReplayStore")
            try:
                return self.replay.get(method, url)
            except ReplayMiss as error:
                self.trace.add("replay.miss", method=method, url=url)
                raise

        response = self.client.request(
            method,
            url,
            headers=headers,
            content=body,
            follow_redirects=False,
        )
        data = ResponseData(
            status_code=response.status_code,
            headers=dict(response.headers),
            body=response.content,
            url=str(response.url),
        )
        if self.recording is not None:
            self.recording.record(method, url, data)
        return data

    @staticmethod
    def _decode(response: ResponseData) -> str:
        content_type = response.header("content-type") or ""
        match = re.search(r"charset=([^;\s]+)", content_type, re.IGNORECASE)
        encoding = match.group(1).strip('"\'') if match else "utf-8"
        try:
            return response.body.decode(encoding, errors="replace")
        except LookupError:
            return response.body.decode("utf-8", errors="replace")
