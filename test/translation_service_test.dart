import 'dart:convert';

import 'package:apk_mesh/core/translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('translates batches through the Microsoft Edge route', () async {
    final client = _FakeClient((request) async {
      expect(request.url.host, 'edge.microsoft.com');
      expect(request.url.path, '/translate/translatetext');
      expect(request.url.queryParameters['to'], 'zh-Hans');
      expect(jsonDecode(await request.body()) as List, ['Hello', 'World']);
      return _jsonResponse([
        {
          'translations': [
            {'text': '你好'},
          ],
        },
        {
          'translations': [
            {'text': '世界'},
          ],
        },
      ]);
    });
    final service = TranslationService(client: client);

    final result = await service.translate(
      ['Hello', 'World'],
      settings: const TranslationSettings(
        provider: TranslationProvider.microsoft,
        targetLanguage: 'zh-CN',
      ),
      deviceId: 'test-device',
    );

    expect(result, ['你好', '世界']);
    service.dispose();
  });

  test(
    'uses the Google browser route when a public key is configured',
    () async {
      final client = _FakeClient((request) async {
        expect(request.url.host, 'translate-pa.googleapis.com');
        expect(request.url.path, '/v1/translateHtml');
        expect(request.headers['x-goog-api-key'], 'public-key');
        final body = jsonDecode(await request.body()) as List;
        expect(body[1], 'te_lib');
        expect(body[0][1], 'auto');
        expect(body[0][2], 'zh-CN');
        return _jsonResponse([
          [
            ['你好'],
          ],
        ]);
      });
      final service = TranslationService(client: client);

      final result = await service.translate(
        ['Hello'],
        settings: const TranslationSettings(
          provider: TranslationProvider.google,
          targetLanguage: 'zh-CN',
          googlePublicKey: 'public-key',
        ),
        deviceId: 'test-device',
      );

      expect(result, ['你好']);
      service.dispose();
    },
  );

  test('gets and refreshes the free-model token route', () async {
    var taskRequests = 0;
    final client = _FakeClient((request) async {
      if (request.url.path.endsWith('/free-model/get-token')) {
        expect(request.url.queryParameters['deviceId'], 'test-device');
        return _jsonResponse({'data': 'temporary-token'});
      }
      expect(request.url.host, 'aigw1.immersivetranslate.com');
      taskRequests += 1;
      final body = jsonDecode(await request.body()) as Map;
      expect(body['task_type'], 'web_page');
      expect(body['stream'], false);
      return _jsonResponse({
        'result': {
          'segments': [
            {'id': 'seg-0', 'text': '你好', 'translated_text': '你好'},
          ],
        },
      });
    });
    final service = TranslationService(client: client);

    final result = await service.translate(
      ['Hello'],
      settings: const TranslationSettings(
        provider: TranslationProvider.freeModel,
        targetLanguage: 'zh-CN',
      ),
      deviceId: 'test-device',
    );

    expect(result, ['你好']);
    expect(taskRequests, 1);
    service.dispose();
  });

  test('maps system and provider-specific language codes', () {
    expect(
      translationLanguageCode('zh-CN', TranslationProvider.microsoft),
      'zh-Hans',
    );
    expect(translationLanguageCode('ja', TranslationProvider.google), 'jp');
  });
}

http.Response _jsonResponse(dynamic value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

extension on http.BaseRequest {
  Future<String> body() async {
    if (this is! http.Request) return '';
    return (this as http.Request).body;
  }
}
