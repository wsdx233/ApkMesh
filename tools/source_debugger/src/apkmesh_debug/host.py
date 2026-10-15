from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable

from .browser_host import BrowserHost
from .http_host import HttpHost
from .models import UnsupportedHostOperation
from .policy import SourcePolicy
from .replay import RecordingStore, ReplayStore
from .trace import TraceRecorder


class SourceHost:
    """Python implementation of the apkmesh object exposed to source scripts."""

    def __init__(
        self,
        manifest,
        trace: TraceRecorder,
        *,
        mode: str = "live",
        replay: ReplayStore | None = None,
        recording: RecordingStore | None = None,
        timeout: float = 30.0,
        headed: bool = False,
        download_dir: Path | None = None,
    ) -> None:
        self.policy = SourcePolicy(manifest)
        self.trace = trace
        self.http = HttpHost(
            self.policy,
            trace,
            mode=mode,
            replay=replay,
            recording=recording,
            timeout=min(timeout, 15.0),
            download_dir=download_dir,
        )
        self.browser = BrowserHost(
            self.policy,
            trace,
            mode=mode,
            replay=replay,
            recording=recording,
            timeout=timeout,
            headed=headed,
        )

    def dispatch(self, name: str, payload: Any) -> Any:
        if name == "apkmesh.request":
            return self.request(
                str(payload.get("url", "")),
                headers=self._string_map(payload.get("headers")),
                method=str(payload.get("method", "GET")),
                body=None if payload.get("body") is None else str(payload.get("body")),
            )
        if name == "apkmesh.browser.open":
            return self.browser.open(str(payload.get("url", "")))
        if name == "apkmesh.browser.waitFor":
            self.browser.wait_for(
                str(payload.get("tabId", "")),
                str(payload.get("selector", "")),
            )
            return True
        if name == "apkmesh.browser.waitForUrlChange":
            return self.browser.wait_for_url_change(
                str(payload.get("tabId", "")),
                str(payload.get("previousUrl", "")),
            )
        if name == "apkmesh.browser.query":
            return self.browser.query(
                str(payload.get("tabId", "")),
                self._dynamic_map(payload.get("selectors")),
            )
        if name == "apkmesh.browser.queryAll":
            return self.browser.query_all(
                str(payload.get("tabId", "")),
                str(payload.get("rootSelector", "")),
                self._dynamic_map(payload.get("selectors")),
            )
        if name == "apkmesh.browser.close":
            self.browser.close(str(payload.get("tabId", "")))
            return True
        if name == "apkmesh.download":
            return self.download(
                str(payload.get("url", "")),
                file_name=payload.get("fileName"),
                headers=self._string_map(payload.get("headers")),
            )
        if name == "apkmesh.detailProgress":
            self.trace.add("detail.progress", **self._dynamic_map(payload.get("update")))
            return True
        raise UnsupportedHostOperation(f"unknown host message: {name}")

    def request(
        self,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        method: str = "GET",
        body: str | None = None,
    ) -> str:
        return self.http.request(url, headers=headers, method=method, body=body)

    def download(
        self,
        url: str,
        *,
        file_name: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> str:
        return self.http.download(url, file_name=file_name, headers=headers)

    def install(self, file_path: str) -> bool:
        self.policy.require_capability("install")
        self.trace.add("install.unsupported", path=file_path)
        raise UnsupportedHostOperation(
            "package installation is Android-only and is disabled in the Python debugger"
        )

    def close(self) -> None:
        self.browser.close_all()
        self.http.close()

    @staticmethod
    def _string_map(value: Any) -> dict[str, str]:
        if not isinstance(value, dict):
            return {}
        return {str(key): str(item) for key, item in value.items()}

    @staticmethod
    def _dynamic_map(value: Any) -> dict[str, Any]:
        return value if isinstance(value, dict) else {}


def as_json_value(value: Any, parse_json: Callable[[str], Any]) -> Any:
    """Convert Python containers to QuickJS values without exposing Python objects."""
    if isinstance(value, (dict, list)):
        return parse_json(json.dumps(value, ensure_ascii=False))
    return value
