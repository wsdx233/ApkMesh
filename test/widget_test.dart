import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:apk_mesh/core/translation_service.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:apk_mesh/main.dart';
import 'package:apk_mesh/widgets/app_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('zh')];
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  testWidgets('shows the four primary destinations', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());

    expect(find.text('发现应用'), findsNothing);
    expect(find.text('主页'), findsWidgets);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('源管理'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('changes the app theme from settings', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('主题'), findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets);

    await tester.tap(find.byType(DropdownButton<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('主题'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('uses consistent setting widths and opens information sheets', (
    tester,
  ) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    final themeTile = find.ancestor(
      of: find.text('主题'),
      matching: find.byType(ListTile),
    );
    final downloadMethodTile = find.ancestor(
      of: find.text('下载方式'),
      matching: find.byType(ListTile),
    );
    final downloadDirectoryTile = find.ancestor(
      of: find.text('下载目录'),
      matching: find.byType(ListTile),
    );
    expect(
      tester.getSize(themeTile).width,
      tester.getSize(downloadMethodTile).width,
    );
    expect(
      tester.getSize(themeTile).width,
      tester.getSize(downloadDirectoryTile).width,
    );

    await tester.tap(find.text('下载目录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('文件会保存到当前平台提供的下载目录'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pumpAndSettle();
  });

  testWidgets('opens the GitHub repository from settings', (tester) async {
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          if (call.method == 'launch') {
            launchedUrl =
                (call.arguments as Map<Object?, Object?>)['url'] as String?;
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, null),
    );

    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    final githubItem = find.text('GitHub 项目');
    await tester.ensureVisible(githubItem);
    await tester.pumpAndSettle();
    expect(find.text('查看源代码、问题和版本发布'), findsOneWidget);

    await tester.tap(githubItem);
    await tester.pumpAndSettle();

    expect(launchedUrl, 'https://github.com/wsdx233/ApkMesh');
  });

  testWidgets('selects the browser download method', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('下载方式'));
    await tester.pumpAndSettle();
    expect(find.byType(RadioListTile<DownloadMethod>), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(RadioListTile<DownloadMethod>),
        matching: find.text('外部下载器'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(RadioListTile<DownloadMethod>),
        matching: find.text('浏览器'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('浏览器'), findsOneWidget);
  });

  testWidgets('settings remain usable at compact mobile width', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('下载方式'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RadioListTile<DownloadMethod>), findsNWidgets(3));
  });

  testWidgets('opens translation configuration in a bottom sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('自动翻译应用名称和简介'), findsNothing);
    expect(find.byType(DropdownButton<TranslationProvider>), findsNothing);

    await tester.tap(find.text('翻译'));
    await tester.pumpAndSettle();

    expect(find.text('翻译设置'), findsOneWidget);
    expect(find.text('自动翻译应用名称和简介'), findsOneWidget);
    expect(find.byType(DropdownButton<TranslationProvider>), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<TranslationProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Translate').last);
    await tester.pumpAndSettle();
    expect(find.text('Google 公共 API Key（可选）'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<TranslationProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('微软 Edge/Bing').last);
    await tester.pumpAndSettle();
    expect(find.text('Google 公共 API Key（可选）'), findsNothing);
  });

  testWidgets('configures unbounded source concurrency in a bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('源并发设置'), findsOneWidget);
    expect(find.text('HTTP 50 · WebView 5'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('源并发设置'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP 请求'), findsOneWidget);
    expect(find.text('隐藏 WebView'), findsOneWidget);
    final values = tester
        .widgetList<Slider>(find.byType(Slider))
        .map((slider) => slider.value)
        .toList();
    expect(values, containsAll(<double>[50, 5]));
    final maximums = tester
        .widgetList<Slider>(find.byType(Slider))
        .map((slider) => slider.max)
        .toList();
    expect(maximums, containsAll(<double>[100, 10]));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '500');
    await tester.enterText(fields.at(1), '25');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('HTTP 500 · WebView 25'), findsOneWidget);
  });

  testWidgets('opens the download manager', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('暂无下载任务'), findsOneWidget);
  });

  testWidgets('only shows the search action on the home page', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('搜索'), findsNothing);

    await tester.tap(find.text('主页').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('搜索'), findsOneWidget);
  });
  testWidgets('shows the English translation action when search opens', (
    tester,
  ) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('翻译为英文'), findsOneWidget);
  });

  testWidgets('shows a completed empty search state', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'missing-package');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('未找到结果'), findsOneWidget);
    expect(find.text('已在所有启用的源中搜索“missing-package”。'), findsOneWidget);
    expect(find.text('输入关键词开始搜索'), findsNothing);
  });

  testWidgets('shows the query in the app bar after searching', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'missing-package');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('search-title')),
    );
    expect(title.data, 'missing-package');

    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-title')), findsNothing);

    await tester.tap(find.text('主页').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-title')), findsOneWidget);
  });

  testWidgets('returns to the home page from search results', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'missing-package');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回主页'), findsOneWidget);
    await tester.tap(find.byTooltip('返回主页'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回主页'), findsNothing);
    expect(find.byKey(const ValueKey('app-title')), findsOneWidget);
    expect(find.text('未找到结果'), findsNothing);
  });

  testWidgets('system back returns from search results to the home page', (
    tester,
  ) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'missing-package');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-title')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回主页'), findsNothing);
    expect(find.byKey(const ValueKey('app-title')), findsOneWidget);
    expect(find.text('未找到结果'), findsNothing);
  });

  testWidgets('loads the next page for a paged catalog tab', (tester) async {
    final state = AppState(host: DemoHostApi());
    final source = _PagedCatalogSource();
    final controller = TextEditingController();
    state.registry.replace(source);
    state.addSource(
      const ApkSource(
        id: _PagedCatalogSource.sourceId,
        name: '分页目录源',
        homepage: 'example.test',
        version: '1.0.0',
        description: '用于验证目录标签分页。',
        status: SourceStatus.enabled,
        builtIn: false,
      ),
    );
    state.setHomeSource(_PagedCatalogSource.sourceId);
    await state.initialize();
    addTearDown(() {
      controller.dispose();
      state.dispose();
    });

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

    expect(find.text('精选'), findsOneWidget);
    expect(find.text('精选应用'), findsOneWidget);
    expect(source.pageCalls, [1]);

    await tester.tap(find.text('分页列表'));
    await tester.pumpAndSettle();
    expect(source.pageCalls, [1, 1]);

    for (var index = 0; index < 12; index++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(source.pageCalls, [1, 1, 2]);
    expect(find.text('第 2 页应用'), findsOneWidget);
  });

  testWidgets('shows page jump only on paged tabs and loads the target page', (
    tester,
  ) async {
    final state = AppState(host: DemoHostApi());
    final source = _PagedCatalogSource();
    state.registry.replace(source);
    state.addSource(
      const ApkSource(
        id: _PagedCatalogSource.sourceId,
        name: '分页目录源',
        homepage: 'example.test',
        version: '1.0.0',
        description: '用于验证目录标签分页。',
        status: SourceStatus.enabled,
        builtIn: false,
      ),
    );
    state.setHomeSource(_PagedCatalogSource.sourceId);
    await state.initialize();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Shell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('跳转页码'), findsNothing);
    await tester.tap(find.text('分页列表'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('跳转页码'), findsOneWidget);

    await tester.tap(find.byTooltip('跳转页码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('page-jump-field')), '7');
    await tester.tap(find.widgetWithText(FilledButton, '跳转'));
    await tester.pumpAndSettle();

    expect(source.pageCalls, [1, 1, 7]);
    expect(find.text('第 7 页应用'), findsOneWidget);
    expect(find.text('第 1 页应用 0'), findsNothing);

    await tester.tap(find.text('精选'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('跳转页码'), findsNothing);
  });

  testWidgets('renders listing description and metadata chips', (tester) async {
    final state = AppState();
    const app = AppDetails(
      id: 'https://example.test/apps/example',
      sourceId: 'example-source',
      name: 'Example App',
      packageName: 'test.example.app',
      version: '1.0.0',
      size: '1 MB',
      updatedAt: '2026-01-01',
      category: 'Tools',
      sourceName: 'Example source',
      iconUrl: '',
      summary: 'Legacy summary',
      description: 'Example description',
      rating: '4.8',
      author: 'Example Team',
      screenshots: [],
      comments: [],
      downloads: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppResultTile(app: app, state: state),
        ),
      ),
    );

    expect(find.text('Example description'), findsOneWidget);
    expect(find.text('Legacy summary'), findsNothing);
    expect(find.text('Example source'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Example Team'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
    expect(find.byIcon(Icons.source_outlined), findsOneWidget);
    expect(find.byIcon(Icons.code_outlined), findsOneWidget);
    state.dispose();
  });

  testWidgets('long press opens app actions and enters selection mode', (
    tester,
  ) async {
    final state = AppState(host: DemoHostApi());
    const app = AppDetails(
      id: 'https://example.test/apps/example',
      sourceId: 'example-source',
      name: 'Example App',
      packageName: 'test.example.app',
      version: '1.0.0',
      size: '1 MB',
      updatedAt: '2026-01-01',
      category: 'Tools',
      sourceName: 'Example source',
      iconUrl: '',
      summary: '',
      screenshots: [],
      comments: [],
      downloads: [],
    );
    var enteredSelection = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppResultTile(
            app: app,
            state: state,
            onEnterSelection: (_) => enteredSelection = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Example App'));
    await tester.pumpAndSettle();
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);

    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();
    expect(enteredSelection, isTrue);
    state.dispose();
  });

  testWidgets('details hides summary and shows metadata chips', (tester) async {
    final state = AppState();
    await state.initialize();
    const app = AppDetails(
      id: 'https://example.test/apps/example',
      sourceId: 'example-source',
      name: 'Example App',
      packageName: 'test.example.app',
      version: '1.0.0',
      size: '1 MB',
      updatedAt: '2026-01-01',
      category: 'Tools',
      sourceName: 'Example source',
      iconUrl: '',
      summary: 'Legacy summary',
      description: 'Example description',
      rating: '4.8',
      author: 'Example Team',
      screenshots: [],
      comments: [],
      downloads: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DetailsSheet(app: app, state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Legacy summary'), findsNothing);
    expect(find.text('Example description'), findsOneWidget);
    expect(find.text('Example source'), findsOneWidget);
    expect(find.byTooltip('刷新详情'), findsOneWidget);
    expect(find.byTooltip('浏览器打开'), findsOneWidget);

    expect(find.byType(Chip), findsNWidgets(8));
    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    expect(
      chips.map((chip) => chip.backgroundColor).toSet(),
      hasLength(chips.length),
    );
    expect(
      chips.map((chip) => chip.labelStyle?.color).toSet(),
      hasLength(chips.length),
    );
    await tester.ensureVisible(find.text('test.example.app'));
    await tester.tap(find.text('test.example.app'));
    await tester.pumpAndSettle();
    expect(find.text('按包名查找'), findsOneWidget);
    state.dispose();
  });

  testWidgets('opens the source batch test sheet', (tester) async {
    final state = AppState(host: DemoHostApi());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SourcesPage(state: state)),
      ),
    );

    await tester.tap(find.text('批量测试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('批量测试源'), findsOneWidget);
    expect(find.text('搜索“hello” · 1 个源'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    state.dispose();
  });

  testWidgets('supports source selection and source test chip', (tester) async {
    final state = AppState(host: DemoHostApi());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SourcesPage(state: state)),
      ),
    );

    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.text('主页'), findsOneWidget);
    await tester.longPress(find.text('APKVision'));
    await tester.pump();
    expect(find.byTooltip('退出多选'), findsOneWidget);

    final overflow = find.byTooltip('批量管理');
    if (overflow.evaluate().isNotEmpty) {
      await tester.tap(overflow);
      await tester.pumpAndSettle();
      expect(find.text('全选'), findsOneWidget);
      await tester.tap(find.text('全选'));
      await tester.pump();
    } else {
      expect(find.byTooltip('全选'), findsOneWidget);
    }
    expect(find.text('已选择 1 个源'), findsOneWidget);

    await tester.tap(find.byTooltip('退出多选'));
    await tester.pump();
    await tester.tap(find.byTooltip('查看测试项目'));
    await tester.pumpAndSettle();
    expect(find.text('暂无可测试项目'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    state.dispose();
  });

  testWidgets('opens the selected source test sheet and updates its status', (
    tester,
  ) async {
    final state = AppState(host: DemoHostApi());
    state.registry.replace(_TestDebugSource());
    state.addSource(
      const ApkSource(
        id: _TestDebugSource.sourceId,
        name: '测试源',
        homepage: 'example.test',
        version: '1.0.0',
        description: '用于测试源调试项目。',
        status: SourceStatus.enabled,
        builtIn: false,
      ),
    );
    await state.initialize();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SourcesPage(state: state)),
      ),
    );

    await tester.tap(find.byTooltip('查看测试项目').last);
    await tester.pumpAndSettle();
    expect(find.text('执行搜索'), findsOneWidget);

    await tester.tap(find.text('执行搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('正在测试'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('测试成功'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pump();
    expect(find.text('测试结果'), findsOneWidget);
    expect(find.text('返回 1 条结果'), findsNWidgets(2));
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pumpAndSettle();

    state.dispose();
  });

  testWidgets('opens the source debug bottom sheet', (tester) async {
    await tester.pumpWidget(const ApkMeshApp());
    await tester.tap(find.byTooltip('调试'));
    await tester.pumpAndSettle();

    expect(find.text('调试信息'), findsOneWidget);
    expect(find.text('WebView 状态'), findsOneWidget);
    expect(find.text('运行日志'), findsOneWidget);
  });
}

class _TestDebugSource implements ApkSourceScript, DebugProjectSource {
  static const sourceId = 'test-debug-source';
  static const project = SourceDebugProject(
    sourceId: sourceId,
    sourceName: '测试源',
    id: 'search',
    name: '执行搜索',
    description: '执行一个可控的异步测试。',
    inputLabel: '关键词',
    placeholder: '输入关键词',
    defaultInput: 'hello',
  );

  @override
  List<SourceDebugProject> get debugProjects => const [project];

  @override
  String get id => sourceId;

  @override
  String get name => '测试源';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<void> dispose() async {}

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    throw UnimplementedError();
  }

  @override
  Future<DebugProjectResult> runDebugProject(
    SourceDebugProject project,
    String input,
    SourceHostApi host,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return DebugProjectResult(
      projectId: project.id,
      sourceId: sourceId,
      title: '搜索完成',
      summary: '返回 1 条结果',
      data: {'input': input},
    );
  }

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => const [];
}

class _PagedCatalogSource implements ApkSourceScript, SourceCatalogScript {
  static const sourceId = 'paged-catalog-source';
  final List<int> pageCalls = [];

  @override
  String get id => sourceId;

  @override
  String get name => '分页目录源';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  bool get supportsCatalog => true;

  @override
  Future<SourceCatalog> catalog(SourceHostApi host) async =>
      const SourceCatalog(
        defaultTabId: 'featured',
        tabs: [
          SourceCatalogTab(
            id: 'featured',
            name: '精选',
            sourceId: sourceId,
            sourceName: '分页目录源',
            paged: false,
          ),
          SourceCatalogTab(
            id: 'paged',
            name: '分页列表',
            sourceId: sourceId,
            sourceName: '分页目录源',
            paged: true,
          ),
        ],
      );

  @override
  Future<SourceCatalogPage> catalogPage(
    String tabId,
    SourceHostApi host, {
    int page = 1,
  }) async {
    pageCalls.add(page);
    if (tabId == 'featured') {
      return SourceCatalogPage(
        tabId: tabId,
        sourceId: id,
        sourceName: name,
        page: page,
        apps: [_listing('featured', '精选应用')],
        hasMore: false,
      );
    }
    return SourceCatalogPage(
      tabId: tabId,
      sourceId: id,
      sourceName: name,
      page: page,
      apps: page == 1
          ? List.generate(
              30,
              (index) => _listing('page-1-$index', '第 1 页应用 $index'),
            )
          : [_listing('page-$page', '第 $page 页应用')],
      hasMore: page == 1,
    );
  }

  AppListing _listing(String appId, String appName) => AppListing(
    id: appId,
    sourceId: id,
    name: appName,
    packageName: '',
    version: '1.0.0',
    size: '1 MB',
    updatedAt: '',
    category: '',
    sourceName: name,
    iconUrl: '',
  );

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => const [];

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}
