import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:apk_mesh/pages/home_page.dart';
import 'package:apk_mesh/pages/sources_page.dart';
import 'package:apk_mesh/widgets/app_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'translation.auto': false});
  });

  testWidgets('source management lazily builds hundreds of sources', (
    tester,
  ) async {
    final state = AppState(host: DemoHostApi());
    for (var index = 0; index < 300; index++) {
      state.addSource(_source(index));
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SourcesPage(state: state)),
      ),
    );
    await tester.pump();

    expect(state.sources, hasLength(301));
    expect(find.byType(SourceTile).evaluate().length, lessThan(20));
    expect(find.text('Scale source 299'), findsNothing);
    state.dispose();
  });

  testWidgets('search lazily builds a large aggregated result set', (
    tester,
  ) async {
    final state = AppState(host: DemoHostApi());
    await state.initialize();
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomePage(state: state, controller: controller),
        ),
      ),
    );
    await tester.pump();
    final home = tester.state<HomePageState>(find.byType(HomePage));
    home
      ..submittedQuery = 'scale'
      ..loading = false
      ..results = List.generate(1000, _listing);
    await tester.pump();

    expect(find.byType(AppResultTile).evaluate().length, lessThan(30));
    expect(find.text('Scale app 999'), findsNothing);

    controller.dispose();
    state.dispose();
  });

  testWidgets('fixed search tabs replace automatically filled source tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(host: DemoHostApi());
    await state.initialize();
    for (var index = 0; index < 5; index++) {
      state.addSource(_source(index));
    }
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomePage(state: state, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final home = tester.state<HomePageState>(find.byType(HomePage));
    controller.text = 'scale';
    await home.search();
    home.results = [_sourceListing('scale-source-4', 'Preview source result')];
    await tester.pump();

    expect(find.text('全部源'), findsOneWidget);
    expect(find.text('APKVision'), findsOneWidget);
    expect(find.text('Scale source 0'), findsNothing);
    final filterButton = find.byTooltip('筛选搜索源');
    expect(
      tester.getCenter(filterButton).dx,
      greaterThan(tester.getTopRight(find.text('APKVision')).dx),
    );

    await tester.tap(filterButton);
    await tester.pumpAndSettle();
    expect(find.text('搜索源标签'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Scale source 4');
    await tester.pump();
    final previewSource = find.widgetWithText(ListTile, 'Scale source 4');
    await tester.ensureVisible(previewSource);
    final previewButton = find.descendant(
      of: previewSource,
      matching: find.byTooltip('临时查看此源结果'),
    );
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(state.searchTabSourceIds, isEmpty);
    expect(find.text('Scale source 4'), findsOneWidget);
    expect(find.text('Preview source result'), findsOneWidget);

    await tester.tap(filterButton);
    await tester.pumpAndSettle();
    for (final sourceName in ['Scale source 3', 'Scale source 4']) {
      await tester.enterText(find.byType(TextField).last, sourceName);
      await tester.pump();
      final fixedSource = find.widgetWithText(ListTile, sourceName);
      await tester.tap(fixedSource);
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();

    expect(state.searchTabSourceIds, ['scale-source-3', 'scale-source-4']);
    expect(find.text('Scale source 3'), findsOneWidget);
    expect(find.text('Scale source 4'), findsOneWidget);
    expect(find.text('APKVision'), findsNothing);
    expect(find.byTooltip('筛选搜索源'), findsOneWidget);

    controller.dispose();
    state.dispose();
  });
}

ApkSource _source(int index) => ApkSource(
  id: 'scale-source-$index',
  name: 'Scale source $index',
  homepage: 'source-$index.example',
  version: '1.0.0',
  description: 'Synthetic scale source',
  status: SourceStatus.enabled,
  builtIn: false,
);

AppListing _sourceListing(String sourceId, String name) => AppListing(
  id: '$sourceId-app',
  sourceId: sourceId,
  name: name,
  packageName: 'example.$sourceId',
  version: '1.0.0',
  size: '1 MB',
  updatedAt: '',
  category: '',
  sourceName: sourceId,
  iconUrl: '',
);

AppListing _listing(int index) => AppListing(
  id: 'scale-app-$index',
  sourceId: 'apkvision-demo',
  name: 'Scale app $index',
  packageName: 'example.scale.$index',
  version: '1.0.0',
  size: '1 MB',
  updatedAt: '',
  category: '',
  sourceName: 'Scale source',
  iconUrl: '',
);
