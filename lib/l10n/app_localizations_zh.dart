// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '主页';

  @override
  String get downloads => '下载';

  @override
  String get downloadAction => '下载';

  @override
  String get favorites => '收藏';

  @override
  String get favoriteAction => '收藏';

  @override
  String get sources => '源管理';

  @override
  String get settings => '设置';

  @override
  String get backHome => '返回主页';

  @override
  String get searchHint => '搜索应用名称或包名';

  @override
  String get translateEnglish => '翻译为英文';

  @override
  String get clearSearch => '清空搜索';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get search => '搜索';

  @override
  String get jumpToPage => '跳转页码';

  @override
  String get debug => '调试';

  @override
  String translationFailed(String error) {
    return '翻译失败：$error';
  }

  @override
  String get debugInformation => '调试信息';

  @override
  String debugCounts(String requests, String logs) {
    return '$requests 个请求 · $logs 条日志';
  }

  @override
  String get clearDebug => '清空调试记录';

  @override
  String get close => '关闭';

  @override
  String get overview => '概览';

  @override
  String get requests => '请求';

  @override
  String get projects => '项目';

  @override
  String get logs => '日志';

  @override
  String get runtime => '运行时';

  @override
  String get quickJsLoaded => 'QuickJS 源已加载';

  @override
  String get usingDemo => '使用演示源';

  @override
  String enabledSources(String names) {
    return '已启用源：$names';
  }

  @override
  String get available => '可用';

  @override
  String get unavailable => '不可用';

  @override
  String runtimeCapabilities(String count, String availability) {
    return '活动标签 $count 个 · 安装能力：$availability';
  }

  @override
  String get webViewStatus => 'WebView 状态';

  @override
  String get noWebViewTabs => '暂无 WebView 标签';

  @override
  String get webViewPreviewHint => '调试项目运行后可点击标签查看页面。';

  @override
  String get recentRequests => '最近请求';

  @override
  String itemCount(String count) {
    return '$count 个';
  }

  @override
  String get noRequests => '暂无请求';

  @override
  String get runtimeLogs => '运行日志';

  @override
  String get noLogs => '暂无日志';

  @override
  String get requestRecords => '请求记录';

  @override
  String requestRecordsCount(String count) {
    return '$count 个 · 点击查看内容';
  }

  @override
  String get noRequestRecords => '暂无请求记录';

  @override
  String get requestRecordsHint => '运行搜索项目或应用搜索后，请求会出现在这里。';

  @override
  String get webViewDetailsHint => '运行“获取应用详情”项目后，可以点开对应标签进行可视化查看。';

  @override
  String get debugProjects => '调试项目';

  @override
  String get noDebugProjects => '源未声明调试项目';

  @override
  String get debugProjectsHint => '源可以在 manifest.debugProjects 中声明可触发的调试流程。';

  @override
  String logCount(String count) {
    return '$count 条';
  }

  @override
  String get logsHint => '执行搜索、详情或调试项目后，运行事件会显示在这里。';

  @override
  String enterValue(String label) {
    return '请输入$label';
  }

  @override
  String debugProjectFailed(String error) {
    return '调试项目失败：$error';
  }

  @override
  String get runDebugProject => '运行调试项目';

  @override
  String get inProgress => '进行中';

  @override
  String get completed => '完成';

  @override
  String get failed => '失败';

  @override
  String requestSummary(String url, String milliseconds, String characters) {
    return '$url\n$milliseconds ms · $characters 字符';
  }

  @override
  String get responseBody => '响应内容';

  @override
  String get requestDetails => '请求详情';

  @override
  String get noResponseBody => '暂无响应内容';

  @override
  String get requestHeaders => '请求头';

  @override
  String get responseHeaders => '响应头';

  @override
  String get status => '状态';

  @override
  String get loading => '正在加载';

  @override
  String get webViewPreview => 'WebView 可视化查看';

  @override
  String get active => '活动';

  @override
  String get history => '历史';

  @override
  String get loadingProgress => '加载中';

  @override
  String get loaded => '已加载';

  @override
  String get loadFailed => '加载失败';

  @override
  String get webViewUnsupported => '当前平台不支持可视化 WebView，仅保留标签和操作记录。';

  @override
  String get closed => '已关闭';

  @override
  String get none => '无';

  @override
  String get noAppWebpage => '当前应用没有可打开的网页地址';

  @override
  String sourcePolicyReadFailed(String error) {
    return '无法读取源权限：$error';
  }

  @override
  String get webpageNotAllowed => '该源不允许打开此网页';

  @override
  String get noBrowser => '系统没有可用的浏览器';

  @override
  String browserOpenFailed(String error) {
    return '浏览器打开失败：$error';
  }

  @override
  String get noSearchableName => '当前应用没有可用于搜索的名称';

  @override
  String get loadingDetails => '正在加载详情';

  @override
  String sourceDetailsFailed(String error) {
    return '源详情加载失败：$error';
  }

  @override
  String downloadLinksFailed(String error) {
    return '下载链接解析失败：$error';
  }

  @override
  String get unfavorite => '取消收藏';

  @override
  String get refreshDetails => '刷新详情';

  @override
  String get openBrowser => '浏览器打开';

  @override
  String get showOriginal => '显示原文';

  @override
  String get translateNameDescription => '翻译名称和简介';

  @override
  String get switchSource => '切换源';

  @override
  String get screenshots => '截图';

  @override
  String get downloadFiles => '下载文件';

  @override
  String get findingDownloads => '正在查找下载项…';

  @override
  String get comments => '评论';

  @override
  String get sourceSearchFailed => '源搜索失败';

  @override
  String partialSourceSearchFailed(String names) {
    return '部分源搜索失败：$names';
  }

  @override
  String get searching => '正在搜索';

  @override
  String get sameNameSearchFailed => '同名应用搜索失败';

  @override
  String get noSameNameApps => '没有找到完全同名的应用';

  @override
  String get firstPageOnly => '仅展示所有启用源的第一页结果。';

  @override
  String get noDownloadLinks => '未找到可用下载链接';

  @override
  String get expandDescription => '... 点击展开';

  @override
  String get downloadStarted => '已开始下载，可在下载页查看进度';

  @override
  String get sentToBrowser => '已交给浏览器处理';

  @override
  String get sentToDownloader => '已交给外部下载器处理';

  @override
  String cannotStartDownload(String error) {
    return '无法开始下载：$error';
  }

  @override
  String get noDownloads => '暂无下载任务';

  @override
  String get noDownloadsHint => '从应用详情中选择文件后，任务会显示在这里。';

  @override
  String selectedDownloads(String count) {
    return '已选择 $count 个下载';
  }

  @override
  String get downloadManager => '下载管理';

  @override
  String get exitSelection => '退出多选';

  @override
  String get cleanDownloads => '清理下载';

  @override
  String get clearAll => '清除全部';

  @override
  String get clearCompleted => '清除已下载';

  @override
  String get selectAll => '全选';

  @override
  String get invertSelection => '反选';

  @override
  String get selectRange => '区间选择';

  @override
  String get pauseSelectedDownloads => '暂停选中下载';

  @override
  String get resumeSelectedDownloads => '继续选中下载';

  @override
  String get cancelSelectedDownloads => '取消选中下载';

  @override
  String get retrySelectedDownloads => '重试选中下载';

  @override
  String get deleteSelectedDownloads => '删除选中下载';

  @override
  String get bulkActions => '批量管理';

  @override
  String get selectRangeHint => '请先选择区间起点和终点';

  @override
  String get cancelSelectedTitle => '取消选中的下载？';

  @override
  String cancelSelectedMessage(String count) {
    return '将取消并移除 $count 个进行中的下载任务。';
  }

  @override
  String get cancelDownload => '取消下载';

  @override
  String get deleteSelectedTitle => '删除选中的下载？';

  @override
  String deleteSelectedMessage(String count) {
    return '将删除 $count 个下载文件及其记录。';
  }

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get clearCompletedTitle => '清除已下载文件？';

  @override
  String get clearAllDownloadsTitle => '清除全部下载？';

  @override
  String clearCompletedMessage(String count) {
    return '将删除 $count 个已下载文件及其记录。';
  }

  @override
  String clearAllDownloadsMessage(String count) {
    return '将删除 $count 个下载文件及其记录，进行中的任务也会取消。';
  }

  @override
  String get clear => '清除';

  @override
  String get deleteDownloadTitle => '删除下载？';

  @override
  String deleteDownloadMessage(String name) {
    return '将删除“$name”及其下载记录。';
  }

  @override
  String get openFailed => '打开失败';

  @override
  String get deleteDownload => '删除下载';

  @override
  String get openDetails => '打开详情';

  @override
  String get resumeDownload => '继续下载';

  @override
  String get pauseDownload => '暂停下载';

  @override
  String get open => '打开';

  @override
  String get install => '安装';

  @override
  String get retryDownload => '重试下载';

  @override
  String downloadedBytes(String size) {
    return '已下载 $size';
  }

  @override
  String get connecting => '正在连接';

  @override
  String downloadSpeed(String size) {
    return '速度 $size/s';
  }

  @override
  String remainingTime(String duration) {
    return '预计 $duration';
  }

  @override
  String get transferNotStarted => '尚未开始传输';

  @override
  String pausedProgress(String progress) {
    return '已暂停 · $progress';
  }

  @override
  String downloadFailedDetail(String error) {
    return '下载失败\n$error';
  }

  @override
  String get unknownError => '未知错误';

  @override
  String get canceled => '已取消';

  @override
  String hoursMinutes(String hours, String minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String hours(String hours) {
    return '$hours 小时';
  }

  @override
  String minutesSeconds(String minutes, String seconds) {
    return '$minutes 分钟 $seconds 秒';
  }

  @override
  String minutes(String minutes) {
    return '$minutes 分钟';
  }

  @override
  String seconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get installedWithShizuku => '已通过 Shizuku 安装';

  @override
  String get sentToInstaller => '已交给系统安装器';

  @override
  String get installationIncomplete => '安装未完成，请检查安装权限后重试';

  @override
  String get installationFailed => '安装失败';

  @override
  String get details => '详情';

  @override
  String errorDetails(String summary) {
    return '$summary详情';
  }

  @override
  String get alreadyFavorites => '所选应用已在收藏中';

  @override
  String appsFavorited(String count) {
    return '已收藏 $count 个应用';
  }

  @override
  String get resolvingDownloadsBackground => '正在后台解析下载链接…';

  @override
  String get batchDownloadNoLinks => '批量下载失败：没有找到可用下载链接';

  @override
  String filesStarted(String count) {
    return '已开始下载 $count 个文件，可在下载页查看进度';
  }

  @override
  String filesStartedWithErrors(String count, String failed) {
    return '已开始下载 $count 个文件，$failed 个应用存在解析或下载问题';
  }

  @override
  String batchDownloadFailed(String error) {
    return '批量下载失败：$error';
  }

  @override
  String get searchSourcesFailed => '搜索源加载失败';

  @override
  String get allSources => '全部源';

  @override
  String get filterSearchSources => '筛选搜索源';

  @override
  String get noEnabledSources => '没有启用的源';

  @override
  String get noEnabledSourcesHint => '请先在源管理中启用一个源。';

  @override
  String get loadingHome => '正在加载首页';

  @override
  String get homeLoadFailed => '首页内容加载失败';

  @override
  String get retry => '重试';

  @override
  String get noCatalog => '暂无目录内容';

  @override
  String get noCatalogHint => '当前主页源没有返回可用标签。';

  @override
  String loadingNamed(String name) {
    return '正在加载$name';
  }

  @override
  String namedLoadFailed(String name) {
    return '$name加载失败';
  }

  @override
  String get noApps => '暂无应用';

  @override
  String get noAppsHint => '该标签没有返回可用应用。';

  @override
  String get nextPageFailed => '加载下一页失败';

  @override
  String get noResults => '未找到结果';

  @override
  String searchedAllSources(String query) {
    return '已在所有启用的源中搜索“$query”。';
  }

  @override
  String noSourceResults(String query) {
    return '当前源没有返回“$query”的结果。';
  }

  @override
  String get sourceRequestIncomplete => '源请求未完成，请打开错误详情查看原因。';

  @override
  String get invalidPage => '请输入大于 0 的页码';

  @override
  String get pageNumber => '页码';

  @override
  String get jump => '跳转';

  @override
  String get searchSourceTabs => '搜索源标签';

  @override
  String get automaticTabs => '恢复自动显示';

  @override
  String get sourceSearchHint => '搜索源名称或域名';

  @override
  String get previewSourceResults => '临时查看此源结果';

  @override
  String get apply => '应用';

  @override
  String get searchErrorDetails => '搜索错误详情';

  @override
  String get copyError => '复制报错信息';

  @override
  String get errorCopied => '已复制报错信息';

  @override
  String get noHistory => '暂无历史记录';

  @override
  String get noFavorites => '暂无收藏应用';

  @override
  String get noHistoryHint => '打开应用详情后会自动记录在这里。';

  @override
  String get noFavoritesHint => '在应用列表或详情页点击书签即可收藏。';

  @override
  String get browsingHistory => '历史记录';

  @override
  String get myFavorites => '我的收藏';

  @override
  String get clearHistory => '清空历史';

  @override
  String get clearFavorites => '清空收藏';

  @override
  String get clearHistoryTitle => '清空历史记录？';

  @override
  String get clearFavoritesTitle => '清空收藏？';

  @override
  String get clearHistoryMessage => '这会移除所有历史记录。';

  @override
  String get clearFavoritesMessage => '这会移除所有收藏应用。';

  @override
  String get clearLibrary => '清空';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get internalDownload => '应用内部';

  @override
  String get browser => '浏览器';

  @override
  String get externalDownloader => '外部下载器';

  @override
  String get theme => '主题';

  @override
  String get downloadDirectory => '下载目录';

  @override
  String get downloadDirectorySummary => '应用内部下载使用系统下载目录';

  @override
  String get downloadDirectoryInternal =>
      '选择“应用内部”时，文件会保存到当前平台提供的下载目录；平台未提供该目录时使用应用文档目录。';

  @override
  String get downloadDirectoryExternal => '选择浏览器或外部下载器时，保存位置由接收下载链接的应用决定。';

  @override
  String get installPermission => '安装权限';

  @override
  String get installPermissionSummary => '安装 APK 前需要允许本应用安装未知来源的应用';

  @override
  String get installUnsupported => '当前平台不支持 APK 安装';

  @override
  String get installPermissionDetails =>
      'APK 安装仅在 Android 平台可用。用户点击安装不受源的安装权限声明限制；源脚本主动调用安装时仍需声明对应权限。';

  @override
  String get legalSafety => '法律与安全';

  @override
  String get legalSafetySummary => '使用第三方源和 APK 文件前请确认授权与可信度';

  @override
  String get legalAuthorization => '请只导入你有权访问和使用的站点源，并遵守对应站点的服务条款与当地法律。';

  @override
  String get legalVerification =>
      'APK Mesh 不验证第三方下载内容。安装前请核验应用来源、包名、版本和签名，并使用可信的安全工具检查文件。';

  @override
  String get legalPermissions =>
      '源声明的网络、浏览器、下载和安装权限会限制脚本可调用的宿主能力，但不会阻止用户手动安装已下载的 APK。';

  @override
  String get githubProject => 'GitHub 项目';

  @override
  String get githubSummary => '查看源代码、问题和版本发布';

  @override
  String get aboutApp => '关于 APK Mesh';

  @override
  String get aboutSummary => '开源 APK 源聚合客户端 · 1.0.0';

  @override
  String get aboutDescription =>
      'APK Mesh 是一个开源 APK 源聚合客户端。应用通过受权限策略约束的独立源脚本搜索应用、解析详情并获取下载地址。';

  @override
  String get appVersion => '版本 1.0.0';

  @override
  String get githubOpenFailed => '无法打开 GitHub 项目';

  @override
  String get downloadMethod => '下载方式';

  @override
  String get internalDownloadHint => '在 APK Mesh 中下载，可查看进度、暂停、继续和安装';

  @override
  String get browserDownloadHint => '使用系统默认浏览器打开下载链接';

  @override
  String get externalDownloaderHint => '选择 ADM、1DM 等支持下载 Intent 的应用';

  @override
  String get externalDownloaderUnsupported => '当前平台不支持外部下载器';

  @override
  String get sourceConcurrency => '源并发设置';

  @override
  String get httpRequests => 'HTTP 请求';

  @override
  String get httpConcurrencyHint => '同时执行的源网络请求数';

  @override
  String get headlessWebView => '隐藏 WebView';

  @override
  String get webViewConcurrencyHint => '同时保持活动的浏览器标签页数';

  @override
  String get restoreDefaults => '恢复默认值';

  @override
  String get concurrency => '并发数';

  @override
  String get minimumOne => '至少为 1';

  @override
  String get shizukuAuthorizedEnabled => '已授权；点击安装后将通过 Shizuku 安装 APK';

  @override
  String get shizukuAuthorizedDisabled => '已授权，打开后通过 Shizuku 安装 APK';

  @override
  String get shizukuNotRunningEnabled => 'Shizuku 未运行，安装前请先启动服务';

  @override
  String get shizukuNotRunningDisabled => '请先启动 Shizuku，再打开此选项';

  @override
  String get shizukuDenied => 'Shizuku 未授予 APK Mesh 权限';

  @override
  String get shizukuUnsupported => '当前平台不支持 Shizuku 安装';

  @override
  String shizukuAuthorizationFailed(String error) {
    return 'Shizuku 授权失败：$error';
  }

  @override
  String get useShizuku => '使用 Shizuku 安装';

  @override
  String get translation => '翻译';

  @override
  String get translationSettings => '翻译设置';

  @override
  String get autoTranslate => '自动翻译应用名称和简介';

  @override
  String get autoTranslateHint => '搜索结果和详情加载后自动请求翻译';

  @override
  String get translationService => '翻译服务';

  @override
  String get targetLanguage => '目标语言';

  @override
  String get googleApiKey => 'Google 公共 API Key（可选）';

  @override
  String get googleApiKeyHint => '留空时使用 Google Translate 浏览器旧接口。';

  @override
  String get translationPrivacy => '翻译文本会发送到所选服务商或其网关。接口不稳定或请求失败时保留原文。';

  @override
  String get waitingForTest => '等待测试';

  @override
  String testInputHint(String label) {
    return '输入$label后开始测试';
  }

  @override
  String get testing => '正在测试';

  @override
  String get testLiveHint => '测试进行中，状态会实时更新';

  @override
  String get testSucceeded => '测试成功';

  @override
  String get testCompleted => '测试已完成';

  @override
  String get testFailed => '测试失败';

  @override
  String get testIncomplete => '测试未完成';

  @override
  String get liveStatus => '实时状态';

  @override
  String requestCount(String count) {
    return '请求 $count 个';
  }

  @override
  String requestStatusCounts(String pending, String completed, String failed) {
    return '进行中 $pending · 已完成 $completed · 失败 $failed';
  }

  @override
  String webViewCount(String count) {
    return 'WebView $count 个';
  }

  @override
  String get recentEvents => '最近事件';

  @override
  String get testResults => '测试结果';

  @override
  String get retest => '重新测试';

  @override
  String get runTest => '运行测试';

  @override
  String get disableFailedTitle => '关闭测试失败的源？';

  @override
  String disableFailedMessage(String count) {
    return '将关闭 $count 个测试失败的源。';
  }

  @override
  String get disableSources => '关闭源';

  @override
  String get batchTestSources => '批量测试源';

  @override
  String batchTestQuery(String query, String count) {
    return '搜索“$query” · $count 个源';
  }

  @override
  String batchTestProgress(
    String completed,
    String total,
    String available,
    String failed,
  ) {
    return '正在测试 · 已完成 $completed/$total · 可用 $available 个 · 失败 $failed 个';
  }

  @override
  String batchTestCounts(String available, String failed) {
    return '可用 $available 个 · 失败 $failed 个';
  }

  @override
  String disableFailedSources(String count) {
    return '关闭失败源 ($count)';
  }

  @override
  String get batchTestIncomplete => '批量测试未完成';

  @override
  String get notTested => '未测试';

  @override
  String sourceTestAvailable(String count) {
    return '可用 · 搜索返回 $count 条';
  }

  @override
  String sourceTestUnavailable(String error) {
    return '不可用 · $error';
  }

  @override
  String get sourceCurrentlyDisabled => ' · 当前已关闭';

  @override
  String get batchTest => '批量测试';

  @override
  String get importSource => '导入源';

  @override
  String selectedSources(String count) {
    return '已选择 $count 个源';
  }

  @override
  String get enableSelectedSources => '开启选中源';

  @override
  String get disableSelectedSources => '关闭选中源';

  @override
  String get enable => '开启';

  @override
  String get disable => '关闭';

  @override
  String sourcesImported(String count) {
    return '已导入 $count 个源';
  }

  @override
  String sourcesImportedWithErrors(String count, String failed) {
    return '已导入 $count 个源，失败 $failed 个';
  }

  @override
  String get sourceUrl => '源 URL';

  @override
  String get importSourceFile => '从系统文件选择 JS 或 ZIP';

  @override
  String get enterSourceUrl => '请输入源 URL';

  @override
  String get importSourceUrl => '从 URL 导入';

  @override
  String get viewTestProjects => '查看测试项目';

  @override
  String get noTestProjects => '暂无可测试项目';

  @override
  String get test => '测试';

  @override
  String get deleteSource => '删除源';

  @override
  String get backgroundDownloadHint => '后台解析下载链接并加入下载任务';

  @override
  String get multiSelect => '多选';

  @override
  String get multiSelectHint => '选择多个应用后批量下载或收藏';

  @override
  String get resolvingDownload => '正在解析下载链接…';

  @override
  String filesStartedPartial(String count) {
    return '已开始下载 $count 个文件，但部分链接处理失败';
  }

  @override
  String downloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String selectedApps(String count) {
    return '已选择 $count 个应用';
  }

  @override
  String get favoriteSelectedApps => '收藏选中应用';

  @override
  String get downloadSelectedApps => '下载选中应用';

  @override
  String get lookupPackage => '按包名查找应用';

  @override
  String get lookupPackageTitle => '按包名查找';

  @override
  String get packageLookupFailed => '包名查找失败';

  @override
  String get noMatchingApps => '未找到对应应用';

  @override
  String get noPackageSources => '没有可用的包名查找源';

  @override
  String get packageSearchedHint => '已在启用的包名查找源中搜索该包名。';

  @override
  String get enablePackageSourceHint => '请先启用声明了包名查找能力的源。';

  @override
  String get saveImage => '保存图片';

  @override
  String imageRequestFailed(String status) {
    return '图片请求失败：HTTP $status';
  }

  @override
  String get imageSaved => '图片已保存到系统相册';

  @override
  String imageSaveFailed(String error) {
    return '保存图片失败：$error';
  }

  @override
  String get demoSourceDescription => '内置演示源，用于验证 APKVision 搜索、详情和下载接口。';

  @override
  String get translationClosed => '翻译服务已关闭';

  @override
  String get translationEmpty => '翻译接口没有返回结果';

  @override
  String providerTranslationFailed(String provider, String error) {
    return '$provider 翻译失败：$error';
  }

  @override
  String shizukuStatusFailed(String error) {
    return '读取 Shizuku 状态失败：$error';
  }

  @override
  String installStatusFailed(String name, String error) {
    return '读取安装状态失败：$name · $error';
  }

  @override
  String get appNotInstalled => '当前 APK 版本尚未安装或无法打开';

  @override
  String get installedAppOpenFailed => '无法打开已安装的应用';

  @override
  String settingsRestoreFailed(String error) {
    return '读取翻译设置失败：$error';
  }

  @override
  String get builtInQuickJsSource => '内置 QuickJS 源';

  @override
  String downloadsRestored(String count) {
    return '恢复 $count 条下载任务';
  }

  @override
  String downloadsRestoreFailed(String error) {
    return '读取下载任务失败：$error';
  }

  @override
  String downloadsSaveFailed(String error) {
    return '[APK Mesh] 保存下载任务失败：$error';
  }

  @override
  String get downloadSourceMissing => '下载源未恢复，请重新导入源后重试';

  @override
  String get scanningSources => '正在扫描内置 QuickJS 源';

  @override
  String bundledSourcesFound(String count) {
    return '发现 $count 个内置源脚本';
  }

  @override
  String sourceLoaded(String path) {
    return '已加载源：$path';
  }

  @override
  String sourceLoadFailed(String path, String error) {
    return 'QuickJS 源加载失败（$path）: $error';
  }

  @override
  String get sourceReadFailed => '无法读取 JS 源脚本';

  @override
  String get sourceImportUnsupported => '当前平台不支持 QuickJS 源导入';

  @override
  String get sourceMissingId => '源 manifest 缺少有效 ID';

  @override
  String sourceIdExists(String id) {
    return '源 ID 已存在：$id';
  }

  @override
  String get sourceHttpsRequired => '源 URL 必须是 HTTPS 地址';

  @override
  String get sourceRuntimeMissing => '源运行时未加载';

  @override
  String batchTestStarted(String query) {
    return '开始批量测试源：搜索“$query”';
  }

  @override
  String batchTestFinished(String available, String failed) {
    return '批量测试完成：可用 $available 个，失败 $failed 个';
  }

  @override
  String searchStarted(String query) {
    return '开始聚合搜索：$query';
  }

  @override
  String sourceExecutionFailed(String source, String error) {
    return '$source 执行失败：$error';
  }

  @override
  String searchFinished(String count) {
    return '聚合搜索完成，结果 $count 条';
  }

  @override
  String packageLookupStarted(String package) {
    return '开始按包名查找：$package';
  }

  @override
  String packageLookupFinished(String count) {
    return '按包名查找完成，结果 $count 条';
  }

  @override
  String searchPageStarted(String page, String query) {
    return '开始加载搜索第 $page 页：$query';
  }

  @override
  String searchPageFinished(String page, String count) {
    return '搜索第 $page 页完成，结果 $count 条';
  }

  @override
  String get noAppDetails => '没有返回应用详情';

  @override
  String candidateNoLinks(String name) {
    return '$name：未找到可用下载链接';
  }

  @override
  String get wrongHomeSource => '该目录标签不属于当前主页源';

  @override
  String sourceDisabled(String id) {
    return '源未启用：$id';
  }

  @override
  String debugProjectStarted(String name, String input) {
    return '开始调试项目：$name · $input';
  }

  @override
  String debugProjectError(String name, String error) {
    return '调试项目失败：$name · $error';
  }

  @override
  String notificationInstallFailed(String name, String error) {
    return '通知安装失败：$name · $error';
  }

  @override
  String get appStateClosed => '应用状态已关闭';

  @override
  String get downloadPermissionMissing => '该源没有声明下载权限';

  @override
  String get downloadUrlDenied => '源权限拒绝访问下载地址';

  @override
  String get noExternalDownloader => '没有可用的外部下载器';

  @override
  String externalDownloadReceived(String method, String name) {
    return '$method已接收：$name';
  }

  @override
  String downloadStarting(String name) {
    return '开始下载：$name';
  }

  @override
  String downloadPausing(String name) {
    return '暂停下载：$name';
  }

  @override
  String downloadPauseFailed(String name, String error) {
    return '暂停下载失败：$name · $error';
  }

  @override
  String downloadResuming(String name) {
    return '继续下载：$name';
  }

  @override
  String downloadResumeFailed(String name, String error) {
    return '继续下载失败：$name · $error';
  }

  @override
  String downloadCanceling(String name) {
    return '取消下载：$name';
  }

  @override
  String downloadCancelCleanupFailed(String name, String error) {
    return '取消下载清理失败：$name · $error';
  }

  @override
  String downloadDeleteFailed(String name, String error) {
    return '删除下载文件失败：$name · $error';
  }

  @override
  String downloadDeleting(String name) {
    return '删除下载：$name';
  }

  @override
  String downloadSessionCleanupFailed(String name, String error) {
    return '清理下载会话失败：$name · $error';
  }

  @override
  String downloadCompleted(String name) {
    return '下载完成：$name';
  }

  @override
  String downloadCanceled(String name) {
    return '已取消下载：$name';
  }

  @override
  String downloadError(String name, String error) {
    return '下载失败：$name · $error';
  }

  @override
  String get downloadNotComplete => '下载文件尚未完成';

  @override
  String get installationInProgress => '该安装任务正在进行';

  @override
  String get microsoftTranslator => '微软 Edge/Bing';

  @override
  String get freeTranslator => '免费翻译服务';

  @override
  String get translationCountMismatch => '翻译接口返回数量与请求不一致';

  @override
  String get microsoftResponseInvalid => 'Microsoft 翻译返回格式无效';

  @override
  String get freeTranslationResponseInvalid => '免费翻译服务返回格式无效';

  @override
  String get freeTranslationToken => '免费翻译服务 Token';

  @override
  String get translationTokenMissing => '免费翻译服务没有返回 Token';

  @override
  String translationJsonInvalid(String error) {
    return '翻译接口返回不是有效 JSON：$error';
  }

  @override
  String get simplifiedChinese => '中文简体';

  @override
  String get traditionalChinese => '中文繁体';

  @override
  String get englishLanguage => '英语';

  @override
  String get japaneseLanguage => '日语';

  @override
  String get koreanLanguage => '韩语';

  @override
  String get spanishLanguage => '西班牙语';

  @override
  String get frenchLanguage => '法语';

  @override
  String get germanLanguage => '德语';

  @override
  String get portugueseLanguage => '葡萄牙语';

  @override
  String get appLanguage => '界面语言';

  @override
  String get appLanguageHint => '仅影响软件界面，不改变源内容的翻译目标语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get autoCheckUpdates => '自动检查更新';

  @override
  String get autoCheckUpdatesSummary => '应用启动时自动检查新版本';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新...';

  @override
  String alreadyLatestVersion(String version) {
    return '当前已是最新版本 ($version)';
  }

  @override
  String updateCheckFailed(String error) {
    return '检查更新失败: $error';
  }

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String currentVersionLabel(String version) {
    return '当前版本: $version';
  }

  @override
  String latestVersionLabel(String version) {
    return '最新版本: $version';
  }

  @override
  String get releaseNotes => '更新日志';

  @override
  String get noReleaseNotes => '暂无更新说明';

  @override
  String get updateAction => '更新';

  @override
  String get dontRemindAgain => '不再提醒';

  @override
  String downloadingUpdate(String percent) {
    return '正在下载更新: $percent%';
  }

  @override
  String downloadUpdateFailed(String error) {
    return '更新下载失败: $error';
  }

  @override
  String get downloadCompleteInstalling => '下载完成，正在准备安装...';

  @override
  String get openInBrowser => '在浏览器中打开';

  @override
  String ignoredVersionHint(String version) {
    return '已忽略版本: $version · 点击恢复提醒';
  }

  @override
  String ignoredVersionRestored(String version) {
    return '已恢复 $version 的更新提醒';
  }
}
