import 'dart:convert';
import 'dart:io';

import 'package:apk_mesh/core/host_factory_io.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SourcePolicy(allowedHosts: {'127.0.0.1'});

  for (final status in [301, 302, 303, 307, 308]) {
    test(
      'native POST redirect $status preserves the established semantics',
      () async {
        final seen = <_Request>[];
        final server = await _serve(seen, redirectStatus: status);
        final host = NativeHostApi();
        addTearDown(host.dispose);
        addTearDown(() => server.close(force: true));

        expect(
          await host.request(
            'http://127.0.0.1:${server.port}/start',
            method: ' post ',
            body: '{"value":"中文"}',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer test',
            },
            policy: policy,
          ),
          'done',
        );
        expect(seen, hasLength(2));
        expect(seen.first.method, 'POST');
        expect(seen.first.body, '{"value":"中文"}');
        expect(seen.last.headers['authorization'], 'Bearer test');
        if (status == 307 || status == 308) {
          expect(seen.last.method, 'POST');
          expect(seen.last.body, seen.first.body);
          expect(
            seen.last.headers['content-type'],
            contains('application/json'),
          );
        } else {
          expect(seen.last.method, 'GET');
          expect(seen.last.body, isEmpty);
          expect(seen.last.headers.containsKey('content-type'), isFalse);
        }
      },
    );
  }

  test(
    'native cross-origin redirect strips explicit credentials on allowed hosts',
    () async {
      final seen = <_Request>[];
      final destination = await _serve(seen);
      final start = await _serve(
        seen,
        redirectStatus: 307,
        redirectUrl: 'http://127.0.0.1:${destination.port}/final',
      );
      final host = NativeHostApi();
      addTearDown(host.dispose);
      addTearDown(() => start.close(force: true));
      addTearDown(() => destination.close(force: true));

      await host.request(
        'http://127.0.0.1:${start.port}/start',
        method: 'POST',
        body: 'payload',
        policy: policy,
        headers: {
          'Authorization': 'Bearer private',
          'Cookie': 'session=private',
          'Proxy-Authorization': 'Basic private',
        },
      );
      expect(seen, hasLength(2));
      expect(seen.last.method, 'POST');
      expect(seen.last.body, 'payload');
      for (final header in ['authorization', 'proxy-authorization', 'cookie']) {
        expect(seen.last.headers.containsKey(header), isFalse);
      }
    },
  );

  test(
    'native POST redirect policy rejects before sending a forbidden request',
    () async {
      final seen = <_Request>[];
      final server = await _serve(
        seen,
        redirectStatus: 307,
        redirectUrl: 'http://localhost/forbidden',
      );
      final host = NativeHostApi();
      addTearDown(host.dispose);
      addTearDown(() => server.close(force: true));

      await expectLater(
        host.request(
          'http://127.0.0.1:${server.port}/start',
          method: 'POST',
          body: 'private',
          policy: policy,
        ),
        throwsStateError,
      );
      expect(seen, hasLength(1));
      await expectLater(
        host.request(
          'http://127.0.0.1:${server.port}/start',
          method: 'DELETE',
          policy: policy,
        ),
        throwsArgumentError,
      );
      expect(seen, hasLength(1));
    },
  );
}

class _Request {
  _Request(this.method, this.body, this.headers);
  final String method;
  final String body;
  final Map<String, String> headers;
}

Future<HttpServer> _serve(
  List<_Request> seen, {
  int? redirectStatus,
  String? redirectUrl,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final headers = <String, String>{};
    request.headers.forEach(
      (name, values) => headers[name] = values.join(', '),
    );
    seen.add(
      _Request(
        request.method,
        await utf8.decoder.bind(request).join(),
        headers,
      ),
    );
    if (request.uri.path == '/start' && redirectStatus != null) {
      request.response.statusCode = redirectStatus;
      request.response.headers.set('Location', redirectUrl ?? '/final');
    } else {
      request.response.write('done');
    }
    await request.response.close();
  });
  return server;
}
