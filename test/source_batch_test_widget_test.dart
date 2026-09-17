import 'dart:async';

import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:apk_mesh/pages/source_test_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('batch source test updates each result as it completes', (
    tester,
  ) async {
    final first = _GatedSource('batch-first', '批量源一');
    final second = _GatedSource('batch-second', '批量源二');
    final state = AppState(host: DemoHostApi());
    for (final source in [first, second]) {
      state.registry.replace(source);
      state.addSource(
        ApkSource(
          id: source.id,
          name: source.name,
          homepage: 'example.test',
          version: '1.0.0',
          description: '批量测试实时更新测试源。',
          status: SourceStatus.enabled,
          builtIn: false,
        ),
      );
    }
    await state.initialize();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SourceBatchTestSheet(
            state: state,
            sourceIds: {first.id, second.id},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('等待测试'), findsNWidgets(2));

    first.complete([_listing(first.id, first.name)]);
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('正在测试 · 已完成 1/2 · 可用 1 个 · 失败 0 个'), findsOneWidget);
    expect(find.text('可用 · 搜索返回 1 条'), findsOneWidget);
    expect(find.text('等待测试'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );

    second.completeError(StateError('测试失败'));
    await tester.pumpAndSettle();

    expect(find.text('可用 1 个 · 失败 1 个'), findsOneWidget);
    expect(find.textContaining('不可用 · Bad state: 测试失败'), findsOneWidget);
  });
}

class _GatedSource implements ApkSourceScript {
  _GatedSource(this.id, this.name);

  @override
  final String id;

  @override
  final String name;

  final Completer<List<AppListing>> _result = Completer<List<AppListing>>();

  void complete(List<AppListing> results) => _result.complete(results);

  void completeError(Object error) => _result.completeError(error);

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) => _result.future;

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}

AppListing _listing(String sourceId, String sourceName) => AppListing(
  id: '$sourceId-app',
  sourceId: sourceId,
  name: '$sourceName 应用',
  packageName: 'example.$sourceId',
  version: '1.0.0',
  size: '1 MB',
  updatedAt: '',
  category: '',
  sourceName: sourceName,
  iconUrl: '',
);
