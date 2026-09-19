import 'dart:convert';
import 'dart:io';

import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/app_update.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:apk_mesh/widgets/update_dialog.dart';
import 'package:apk_mesh/widgets/update_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion', () {
    test('parses version strings correctly', () {
      final v1 = AppVersion.parse('1.0.0');
      expect(v1.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 0);
      expect(v1.build, 0);
      expect(v1.preRelease, '');

      final v2 = AppVersion.parse('v1.2.3+4');
      expect(v2.major, 1);
      expect(v2.minor, 2);
      expect(v2.patch, 3);
      expect(v2.build, 4);

      final v3 = AppVersion.parse('V2.0.1-beta.1');
      expect(v3.major, 2);
      expect(v3.minor, 0);
      expect(v3.patch, 1);
      expect(v3.preRelease, 'beta.1');
    });

    test('compares versions accurately', () {
      expect(AppVersion.parse('1.0.1') > AppVersion.parse('1.0.0'), isTrue);
      expect(AppVersion.parse('v1.0.1') > AppVersion.parse('1.0.0'), isTrue);
      expect(AppVersion.parse('1.1.0') > AppVersion.parse('1.0.9'), isTrue);
      expect(AppVersion.parse('2.0.0') > AppVersion.parse('1.9.9'), isTrue);
      expect(AppVersion.parse('1.0.0+2') > AppVersion.parse('1.0.0+1'), isTrue);
      expect(AppVersion.parse('1.0.0') > AppVersion.parse('1.0.0-rc1'), isTrue);
      expect(AppVersion.parse('1.0.0') == AppVersion.parse('v1.0.0'), isTrue);
      expect(AppVersion.parse('1.0.0') < AppVersion.parse('1.0.1'), isTrue);
      expect(AppVersion.parse('1.0.0') >= AppVersion.parse('1.0.0'), isTrue);
    });
  });

  group('AppReleaseInfo', () {
    test('deserializes GitHub release JSON and detects APK asset', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'Release 1.1.0',
        'body': 'What is new:\n- Added dark mode\n- Bug fixes',
        'html_url': 'https://github.com/wsdx233/ApkMesh/releases/tag/v1.1.0',
        'published_at': '2026-09-19T00:00:00Z',
        'assets': [
          {
            'name': 'sources.zip',
            'size': 1024,
            'browser_download_url': 'https://example.com/sources.zip',
            'content_type': 'application/zip',
          },
          {
            'name': 'apkmesh-v1.1.0.apk',
            'size': 61209079,
            'browser_download_url': 'https://example.com/apkmesh-v1.1.0.apk',
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.tagName, 'v1.1.0');
      expect(release.name, 'Release 1.1.0');
      expect(release.body, contains('Added dark mode'));
      expect(
        release.htmlUrl,
        'https://github.com/wsdx233/ApkMesh/releases/tag/v1.1.0',
      );
      expect(release.apkAsset, isNotNull);
      expect(release.apkAsset!.name, 'apkmesh-v1.1.0.apk');
      expect(release.apkAsset!.isApk, isTrue);
      expect(release.hasUpdate(AppVersion.parse('1.0.0')), isTrue);
      expect(release.hasUpdate(AppVersion.parse('1.2.0')), isFalse);
    });
  });

  group('UpdateService', () {
    test('fetchLatestRelease parses release response from GitHub', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.0.5',
              'name': 'v1.0.5',
              'body': 'New release notes',
              'html_url':
                  'https://github.com/wsdx233/ApkMesh/releases/tag/v1.0.5',
              'assets': [
                {
                  'name': 'app-release.apk',
                  'size': 50000000,
                  'browser_download_url': 'https://example.com/app-release.apk',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(client: mockClient);
      final release = await service.fetchLatestRelease();
      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.5');
      expect(release.apkAsset?.name, 'app-release.apk');
    });

    test('downloadApk streams content and tracks progress', () async {
      final mockClient = MockClient((request) async {
        final bytes = utf8.encode('mock apk file content with some bytes');
        return http.Response.bytes(
          bytes,
          200,
          headers: {'content-length': bytes.length.toString()},
        );
      });

      final service = UpdateService(client: mockClient);
      final tempFile = File('${Directory.systemTemp.path}/test-update.apk');

      try {
        var progressCalled = false;
        final downloaded = await service.downloadApk(
          const AppReleaseAsset(
            name: 'test.apk',
            size: 37,
            downloadUrl: 'https://example.com/test.apk',
          ),
          destinationFile: tempFile,
          onProgress: (received, total) {
            progressCalled = true;
            expect(received, greaterThan(0));
            expect(total, 37);
          },
        );

        expect(progressCalled, isTrue);
        expect(await downloaded.exists(), isTrue);
        expect(
          await downloaded.readAsString(),
          'mock apk file content with some bytes',
        );
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });

  group('AppState update management', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'updates and persists autoCheckUpdates and ignoredUpdateVersion',
      () async {
        final state = AppState(
          host: DemoHostApi(),
          updateService: UpdateService(
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(state.autoCheckUpdates, isTrue);
        expect(state.ignoredUpdateVersion, isNull);

        await state.setAutoCheckUpdates(false);
        expect(state.autoCheckUpdates, isFalse);

        await state.setIgnoredUpdateVersion('v1.0.2');
        expect(state.ignoredUpdateVersion, 'v1.0.2');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('update.autoCheck'), isFalse);
        expect(prefs.getString('update.ignoredVersion'), 'v1.0.2');

        await state.clearIgnoredUpdateVersion();
        expect(state.ignoredUpdateVersion, isNull);
        expect(prefs.getString('update.ignoredVersion'), isNull);

        state.dispose();
      },
    );

    test(
      'checkForUpdates respects autoCheckUpdates and ignored version on automatic check',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.0.2',
              'html_url':
                  'https://github.com/wsdx233/ApkMesh/releases/tag/v1.0.2',
              'assets': [],
            }),
            200,
          );
        });

        final updateService = UpdateService(client: mockClient);
        final state = AppState(
          host: DemoHostApi(),
          updateService: updateService,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Auto check enabled, not ignored -> returns release
        final result1 = await state.checkForUpdates(manual: false);
        expect(result1, isNotNull);
        expect(result1!.tagName, 'v1.0.2');

        // Ignore v1.0.2
        await state.setIgnoredUpdateVersion('v1.0.2');
        final result2 = await state.checkForUpdates(manual: false);
        expect(result2, isNull); // Suppressed because ignored

        // Manual check ignores the ignored version and still returns it
        final result3 = await state.checkForUpdates(manual: true);
        expect(result3, isNotNull);
        expect(result3!.tagName, 'v1.0.2');

        // Auto check disabled
        await state.clearIgnoredUpdateVersion();
        await state.setAutoCheckUpdates(false);
        final result4 = await state.checkForUpdates(manual: false);
        expect(result4, isNull); // Suppressed because auto check disabled

        // Manual check still works when auto check disabled
        final result5 = await state.checkForUpdates(manual: true);
        expect(result5, isNotNull);

        state.dispose();
      },
    );
  });

  group('Update UI Widgets', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('UpdateDialog shows options: 不再提醒, 关闭, 更新', (tester) async {
      final state = AppState(
        host: DemoHostApi(),
        updateService: UpdateService(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      final release = AppReleaseInfo(
        tagName: 'v1.2.0',
        version: AppVersion.parse('1.2.0'),
        body: 'Awesome new features!',
        htmlUrl: 'https://github.com/wsdx233/ApkMesh/releases/tag/v1.2.0',
        assets: [
          const AppReleaseAsset(
            name: 'apkmesh-v1.2.0.apk',
            size: 10485760,
            downloadUrl: 'https://example.com/apkmesh.apk',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showUpdateDialog(context, state: state, release: release),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check dialog content
      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('Awesome new features!'), findsOneWidget);
      expect(find.text('apkmesh-v1.2.0.apk · 10.0 MB'), findsOneWidget);

      // Check the 3 required options
      expect(
        find.byKey(const ValueKey('update-dialog-dont-remind')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('update-dialog-close')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('update-dialog-update')),
        findsOneWidget,
      );
      expect(find.text('不再提醒'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('更新'), findsOneWidget);

      // Tap 不再提醒
      await tester.tap(find.byKey(const ValueKey('update-dialog-dont-remind')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(state.ignoredUpdateVersion, 'v1.2.0');

      state.dispose();
    });

    testWidgets(
      'UpdateSettingsSection renders switch and manual check button',
      (tester) async {
        final state = AppState(
          host: DemoHostApi(),
          updateService: UpdateService(
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: UpdateSettingsSection(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        // Check elements
        expect(find.text('自动检查更新'), findsOneWidget);
        expect(find.text('检查更新'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('setting-auto-check-update')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('setting-check-for-updates')),
          findsOneWidget,
        );

        // Toggle auto update switch
        await tester.tap(
          find.byKey(const ValueKey('setting-auto-check-update')),
        );
        await tester.pumpAndSettle();
        expect(state.autoCheckUpdates, isFalse);

        // Set ignored version and verify restore tile appears
        await state.setIgnoredUpdateVersion('v1.5.0');
        await tester.pumpAndSettle();
        expect(find.textContaining('已忽略版本: v1.5.0'), findsOneWidget);

        // Tap restore ignored version
        await tester.tap(
          find.byKey(const ValueKey('setting-ignored-update-version')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(state.ignoredUpdateVersion, isNull);

        state.dispose();
      },
    );

    testWidgets(
      'UpdateSettingsSection manual check opens dialog when update available',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tag_name': 'v2.0.0',
              'body': 'Major 2.0 release!',
              'html_url':
                  'https://github.com/wsdx233/ApkMesh/releases/tag/v2.0.0',
              'assets': [
                {
                  'name': 'apkmesh-v2.0.0.apk',
                  'size': 20480000,
                  'browser_download_url': 'https://example.com/2.0.apk',
                },
              ],
            }),
            200,
          );
        });

        final state = AppState(
          host: DemoHostApi(),
          updateService: UpdateService(client: mockClient),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: UpdateSettingsSection(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('setting-check-for-updates')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('发现新版本'), findsOneWidget);
        expect(find.text('v2.0.0'), findsOneWidget);

        state.dispose();
      },
    );

    testWidgets(
      'UpdateSettingsSection manual check shows SnackBar when already latest version',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.0.0',
              'body': 'Initial release',
              'html_url':
                  'https://github.com/wsdx233/ApkMesh/releases/tag/v1.0.0',
              'assets': [],
            }),
            200,
          );
        });

        final state = AppState(
          host: DemoHostApi(),
          updateService: UpdateService(client: mockClient),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: UpdateSettingsSection(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('setting-check-for-updates')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('当前已是最新版本'), findsOneWidget);

        state.dispose();
      },
    );
  });
}
