import json
from pathlib import Path

import httpx
import pytest

from apkmesh_debug.http_host import HttpHost
from apkmesh_debug.models import PolicyError, SourceManifest
from apkmesh_debug.policy import SourcePolicy
from apkmesh_debug.replay import ReplayStore
from apkmesh_debug.trace import TraceRecorder


def test_replay_download_passes_headers(tmp_path: Path):
    (tmp_path / "replay.json").write_text(
        json.dumps(
            {
                "responses": {
                    "GET https://example.test/file.apk": {
                        "status": 200,
                        "body": "apk-bytes",
                    }
                }
            }
        ),
        encoding="utf-8",
    )
    manifest = SourceManifest.from_raw(
        {
            "id": "test",
            "name": "Test",
            "permissions": {"network": ["example.test"], "download": True},
        }
    )
    trace = TraceRecorder()
    host = HttpHost(
        SourcePolicy(manifest),
        trace,
        mode="replay",
        replay=ReplayStore(tmp_path),
        download_dir=tmp_path / "downloads",
    )

    path = host.download(
        "https://example.test/file.apk",
        headers={"Referer": "https://example.test/page"},
    )

    assert Path(path).read_bytes() == b"apk-bytes"
    request = next(event for event in trace.events if event["event"] == "http.request")
    assert request["headers"]["Referer"] == "https://example.test/page"
    host.close()


def test_replay_redirect_is_checked_against_source_policy(tmp_path: Path):
    (tmp_path / "replay.json").write_text(
        json.dumps(
            {
                "responses": {
                    "GET https://example.test/start": {
                        "status": 302,
                        "headers": {"location": "https://evil.test/final"},
                        "body": "",
                    }
                }
            }
        ),
        encoding="utf-8",
    )
    manifest = SourceManifest.from_raw(
        {
            "id": "test",
            "name": "Test",
            "permissions": {"network": ["example.test"]},
        }
    )
    host = HttpHost(
        SourcePolicy(manifest),
        TraceRecorder(),
        mode="replay",
        replay=ReplayStore(tmp_path),
    )

    with pytest.raises(PolicyError):
        host.fetch("https://example.test/start")
    host.close()


@pytest.mark.parametrize("status", [301, 302, 303, 307, 308])
def test_post_redirect_preserves_or_discards_body_and_entity_headers(status):
    manifest = SourceManifest.from_raw({"id": "test", "name": "Test", "permissions": {"network": ["example.test"]}})
    host = HttpHost(SourcePolicy(manifest), TraceRecorder())
    requests = []

    def respond(request):
        requests.append(request)
        if request.url.path == "/start":
            return httpx.Response(status, headers={"Location": "/final"})
        return httpx.Response(200, text="done")

    host.client.close()
    host.client = httpx.Client(transport=httpx.MockTransport(respond))
    try:
        assert host.request(
            "https://example.test/start", method=" post ", body='{"value":"中文"}',
            headers={"Content-Type": "application/json", "Authorization": "Bearer test"},
        ) == "done"
        assert requests[0].method == "POST"
        assert requests[0].content.decode() == '{"value":"中文"}'
        redirected = requests[1]
        assert redirected.headers["authorization"] == "Bearer test"
        if status in {307, 308}:
            assert redirected.method == "POST"
            assert redirected.content == requests[0].content
            assert redirected.headers["content-type"] == "application/json"
        else:
            assert redirected.method == "GET"
            assert redirected.content == b""
            assert "content-type" not in redirected.headers
            assert "content-length" not in redirected.headers
    finally:
        host.close()


def test_cross_origin_redirect_strips_explicit_credentials_even_for_allowed_host():
    manifest = SourceManifest.from_raw({"id": "test", "name": "Test", "permissions": {"network": ["example.test", "other.test"]}})
    host = HttpHost(SourcePolicy(manifest), TraceRecorder())
    requests = []

    def respond(request):
        requests.append(request)
        if request.url.host == "example.test":
            return httpx.Response(307, headers={"Location": "https://other.test/final"})
        return httpx.Response(200, text="done")

    host.client.close()
    host.client = httpx.Client(transport=httpx.MockTransport(respond))
    try:
        host.request("https://example.test/start", method="POST", body="payload", headers={
            "Authorization": "Bearer private", "Cookie": "session=private",
            "Proxy-Authorization": "Basic private", "Host": "example.test",
        })
        assert len(requests) == 2
        assert requests[1].method == "POST"
        assert requests[1].content == b"payload"
        assert requests[1].headers["host"] == "other.test"
        for key in ("authorization", "proxy-authorization", "cookie"):
            assert key not in requests[1].headers
    finally:
        host.close()


def test_post_redirect_to_forbidden_host_never_sends_second_request():
    manifest = SourceManifest.from_raw({"id": "test", "name": "Test", "permissions": {"network": ["example.test"]}})
    host = HttpHost(SourcePolicy(manifest), TraceRecorder())
    requests = []

    def respond(request):
        requests.append(request)
        return httpx.Response(307, headers={"Location": "https://evil.test/final"})

    host.client.close()
    host.client = httpx.Client(transport=httpx.MockTransport(respond))
    try:
        with pytest.raises(PolicyError):
            host.request("https://example.test/start", method="POST", body="private")
        assert len(requests) == 1
        with pytest.raises(ValueError, match="GET and POST"):
            host.request("https://example.test/start", method="DELETE")
        assert len(requests) == 1
    finally:
        host.close()
