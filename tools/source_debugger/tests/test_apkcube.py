import json
from pathlib import Path

import pytest

from apkmesh_debug.host import SourceHost
from apkmesh_debug.models import SourceHostError
from apkmesh_debug.replay import ReplayStore
from apkmesh_debug.runtime import SourceRuntime
from apkmesh_debug.trace import TraceRecorder


REPOSITORY = Path(__file__).resolve().parents[3]
FIXTURE = REPOSITORY / 'tools/source_debugger/examples/fixtures/apkcube'
DETAIL_URL = 'https://apkcube.com/chatgpt/com.openai.chatgpt'


class CapturingReplayHost(SourceHost):
    def __init__(self, manifest, trace):
        super().__init__(manifest, trace, mode='replay', replay=ReplayStore(FIXTURE))
        self.requests = []

    def request(self, url, *, headers=None, method='GET', body=None):
        self.requests.append((url, method, body, headers))
        return super().request(url, headers=headers, method=method, body=body)


@pytest.fixture
def apkcube():
    trace = TraceRecorder()
    runtime = SourceRuntime(REPOSITORY / 'assets/sources/apkcube.js', None, trace)
    host = CapturingReplayHost(runtime.manifest, trace)
    runtime.attach_host(host)
    try:
        yield runtime, host, trace
    finally:
        host.close()
        runtime.close()


def test_observed_apkcube_search_pagination_and_exact_package_redirect(apkcube):
    runtime, host, _ = apkcube
    apps = runtime.call('search', 'chatgpt', 1)
    assert len(apps) == 3  # Fixture is deliberately a three-card excerpt.
    assert apps[0]['name'] == 'ChatGPT'
    assert apps[0]['packageName'] == 'com.openai.chatgpt'
    assert apps[0]['iconUrl'].startswith('https://icons.apkcube.com/')
    assert runtime.call('search', 'chatgpt', 2) == []
    assert host.requests[-1][0] == 'https://apkcube.com/search?q=chatgpt&page=2'
    assert runtime.call('packageLookupUrl', 'com.openai.chatgpt') == DETAIL_URL
    assert host.requests[-1][0] == 'https://apkcube.com/search?q=com.openai.chatgpt'


def test_observed_apkcube_detail_images_and_flutter_candidate_roundtrip(apkcube):
    runtime, host, trace = apkcube
    app = runtime.call('detailsMetadata', DETAIL_URL)
    assert app['name'] == 'ChatGPT'
    assert app['packageName'] == 'com.openai.chatgpt'
    assert app['version'] == '1.2026.279'
    assert app['updatedAt'] == '2026-10-11'
    assert app['iconUrl'] == 'https://icons.apkcube.com/com.openai.chatgpt?v=16vh0yq'
    assert len(app['screenshots']) == 8
    assert all(url.startswith('https://play-lh.googleusercontent.com/') for url in app['screenshots'])
    # Mirrors SourceDownloadCandidate.toJson: no packageName/apkId survives.
    candidate = {key: value for key, value in app['downloadCandidates'][0].items()
                 if key in {'label', 'url', 'size', 'headers'}}
    assert candidate['url'] == DETAIL_URL + '/download'
    with pytest.raises(SourceHostError, match='HTTP 403'):
        runtime.call('resolveDownloads', [candidate], 'offline-resolution')
    api_calls = host.requests[1:]
    assert [(url, method) for url, method, _, _ in api_calls] == [
        ('https://apkcube.com/api/apps/com.openai.chatgpt/apks', 'GET'),
        ('https://apkcube.com/api/apps/com.openai.chatgpt/download-token', 'POST'),
        ('https://apkcube.com/api/downloads/request', 'POST'),
    ]
    assert api_calls[1][2] is None
    assert json.loads(api_calls[2][2]) == {
        'packageName': 'com.openai.chatgpt', 'apkId': '68784',
        'install': False, 'pageToken': 'OFFLINE_REPLAY_TOKEN_NOT_VALID',
    }
    for _, _, _, headers in api_calls:
        assert headers['Origin'] == 'https://apkcube.com'
        assert headers['Referer'] == DETAIL_URL + '/download'
    progress = [event for event in trace.events if event['event'] == 'detail.progress']
    assert len(progress) == 1
    assert progress[0]['downloads'] == []
    assert 'HTTP 403' in progress[0]['error']
    assert 'api/downloads/request' in progress[0]['error']


def test_apkcube_does_not_silently_hide_api_error_payload(apkcube):
    runtime, host, _ = apkcube
    # HTTP-success JSON can also carry the observed API refusal payload.
    record = host.http.replay.responses['POST https://apkcube.com/api/downloads/request']
    record['status'] = 200
    with pytest.raises(SourceHostError, match='FIREWALL_BLOCKED: This request was refused'):
        runtime.call('resolveDownloads', [{'label': 'ChatGPT', 'url': DETAIL_URL + '/download'}], None)


def test_apkcube_exact_lookup_rejects_redirect_to_different_package(apkcube):
    runtime, host, _ = apkcube
    record = host.http.replay.responses['GET https://apkcube.com/search?q=com.openai.chatgpt']
    record.pop('body_file')
    record['body'] = '<meta http-equiv="refresh" content="1;url=/other/com.other.app" />'
    assert runtime.call('packageLookupUrl', 'com.openai.chatgpt') == ''
