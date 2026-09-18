import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'concurrency_limiter.dart';
import 'models.dart';
import 'debug_log.dart';

class BrowserTabViewHandle {
  const BrowserTabViewHandle({
    this.headlessWebView,
    required this.keepAlive,
    required this.policy,
  });

  final HeadlessInAppWebView? headlessWebView;
  final InAppWebViewKeepAlive keepAlive;
  final SourcePolicy policy;

  bool get attachesHeadlessWebView => headlessWebView != null;
}

class SourcePolicy {
  const SourcePolicy({
    required this.allowedHosts,
    this.allowBrowser = false,
    this.allowDownload = false,
    this.allowInstall = false,
  });

  final Set<String> allowedHosts;
  final bool allowBrowser;
  final bool allowDownload;
  final bool allowInstall;

  bool permitsInstall({required bool userInitiated}) =>
      userInitiated || allowInstall;

  bool permits(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any((rule) {
      final normalized = rule.toLowerCase();
      if (normalized == '*') return true;
      if (normalized.startsWith('*.')) {
        final suffix = normalized.substring(1);
        return host.endsWith(suffix) && host.length > suffix.length;
      }
      return host == normalized;
    });
  }
}

abstract interface class SourceHostApi {
  bool get supportsBrowser;
  bool get supportsInstall;
  bool get supportsShizuku;
  bool hasDownloadSession(String downloadId);
  List<BrowserTabDebugInfo> get browserTabs;

  Future<String> request(
    String url, {
    Map<String, String> headers = const {},
    required SourcePolicy policy,
  });

  Future<List<int>> requestBytes(
    String url, {
    Map<String, String> headers = const {},
    required SourcePolicy policy,
  });

  Future<String> browserOpen(String url, {required SourcePolicy policy});
  Future<void> browserWaitFor(String tabId, String selector);
  Future<String> browserWaitForUrlChange(String tabId, String previousUrl);
  Future<Map<String, dynamic>> browserQuery(
    String tabId,
    Map<String, dynamic> selectors,
  );
  Future<List<Map<String, dynamic>>> browserQueryAll(
    String tabId,
    String rootSelector,
    Map<String, dynamic> selectors,
  );
  Future<void> browserClose(String tabId);
  BrowserTabViewHandle? browserTabView(String tabId);
  void browserAdoptController(String tabId, InAppWebViewController controller);

  Future<String> download(
    String url, {
    Map<String, String> headers = const {},
    String? downloadId,
    String? fileName,
    required SourcePolicy policy,
    void Function(int received, int? total)? onProgress,
  });
  Future<void> pauseDownload(String downloadId);
  Future<void> resumeDownload(String downloadId);
  Future<void> cancelDownload(String downloadId);
  Future<void> removeDownloadFiles(String downloadId, {String? filePath});

  Future<bool> install(
    String filePath, {
    required SourcePolicy policy,
    bool userInitiated = false,
  });
  Future<bool> canInstallPackages();
  Future<void> requestInstallPermission();
  Future<ApkInstallInfo> inspectInstall(String filePath);
  Future<bool> openInstalled(String packageName);
  void setInstallMethod(InstallMethod method);
  Future<ShizukuStatus> shizukuStatus();
  Future<ShizukuStatus> requestShizukuPermission();
  Future<void> dispose();
}

abstract interface class SourceHostConcurrencyApi {
  void setSourceConcurrency(SourceConcurrencySettings settings);
}

class SourceSearchCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

abstract interface class ApkSourceScript {
  String get id;
  String get name;
  SourcePolicy get policy;
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  });
  Future<AppDetails> details(String appId, SourceHostApi host);
  Future<void> dispose();
}

/// Optional source capability for exact Android package-name lookup.
abstract interface class SourcePackageLookupScript {
  bool get supportsPackageLookup;
  Future<String?> packageLookupUrl(String packageName, SourceHostApi host);
}

/// Optional metadata exposed by scripts loaded from a manifest.
abstract interface class SourceDetailProgressScript {
  bool get supportsDetailProgress;
  Future<SourceDetailsMetadata> detailsMetadata(
    String appId,
    SourceHostApi host,
  );
  Future<List<SourceDownload>> resolveDownloads(
    List<SourceDownloadCandidate> candidates,
    SourceHostApi host, {
    required void Function(
      int index,
      List<SourceDownload>? files,
      String? error,
    )
    onProgress,
  });
}

abstract interface class SourceManifestProvider {
  String get version;
  String get homepage;
  String get description;
}

abstract interface class SourceCatalogScript {
  bool get supportsCatalog;
  Future<SourceCatalog> catalog(SourceHostApi host);
  Future<SourceCatalogPage> catalogPage(
    String tabId,
    SourceHostApi host, {
    int page = 1,
  });
}

abstract interface class DebugProjectSource {
  List<SourceDebugProject> get debugProjects;
  Future<DebugProjectResult> runDebugProject(
    SourceDebugProject project,
    String input,
    SourceHostApi host,
  );
}

bool _isAsciiWordChar(int codeUnit) {
  return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
      (codeUnit >= 65 && codeUnit <= 90) || // A-Z
      (codeUnit >= 97 && codeUnit <= 122); // a-z
}

bool _containsWordBoundary(String text, String pattern) {
  if (pattern.isEmpty) return false;
  var startIndex = 0;
  while (true) {
    final index = text.indexOf(pattern, startIndex);
    if (index == -1) return false;
    final beforeOk =
        index == 0 || !_isAsciiWordChar(text.codeUnitAt(index - 1));
    final afterIndex = index + pattern.length;
    final afterOk =
        afterIndex >= text.length ||
        !_isAsciiWordChar(text.codeUnitAt(afterIndex));
    if (beforeOk && afterOk) return true;
    startIndex = index + 1;
  }
}

List<String> _searchKeywords(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const [];
  final unique = <String>{};
  for (final keyword in normalized.split(RegExp(r'[\s,，、;；|/\\_-]+'))) {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) unique.add(trimmed);
  }
  return unique.toList(growable: false);
}

class SearchResultRanker {
  SearchResultRanker(String query)
    : rawQuery = query.trim().toLowerCase(),
      _keywords = _searchKeywords(query);

  final String rawQuery;
  final List<String> _keywords;

  static const _spamKeywords = [
    'guide',
    'tips',
    'tutorial',
    'wallpaper',
    'wallpapers',
    'cheat',
    'cheats',
    'walkthrough',
    'stickers',
    'sticker',
    'mod menu',
    '指南',
    '攻略',
    '教程',
    '壁纸',
    '贴纸',
  ];

  int score(AppListing app) {
    if (rawQuery.isEmpty) return 0;
    final title = app.name.trim().toLowerCase();
    final pkg = app.packageName.trim().toLowerCase();

    var result = 0;
    final queryMatchesTitleExactly = title == rawQuery;
    final queryMatchesPkgExactly = pkg.isNotEmpty && pkg == rawQuery;

    // 1. 完全精确匹配（Exact Match）—— 最高优先级
    if (queryMatchesTitleExactly) {
      result += 100000;
    }
    if (queryMatchesPkgExactly) {
      result += 90000;
    }

    // 2. 前缀匹配（Prefix Match）
    if (!queryMatchesTitleExactly) {
      if (title.startsWith(rawQuery)) {
        final boundary =
            title.length == rawQuery.length ||
            !_isAsciiWordChar(title.codeUnitAt(rawQuery.length));
        result += boundary ? 40000 : 30000;
      } else if (pkg.isNotEmpty && pkg.startsWith(rawQuery)) {
        result += 25000;
      }
    }

    // 3. 完整短语包含（Phrase Match）
    if (!queryMatchesTitleExactly && !title.startsWith(rawQuery)) {
      if (rawQuery.length > 1 && title.contains(rawQuery)) {
        result += _containsWordBoundary(title, rawQuery) ? 20000 : 12000;
      } else if (pkg.isNotEmpty && pkg.contains(rawQuery)) {
        result += 10000;
      }
    }

    // 4. 独立关键词命中统计
    var matchedCount = 0;
    for (final keyword in _keywords) {
      if (title.contains(keyword)) {
        matchedCount += 1;
        result += _containsWordBoundary(title, keyword) ? 2000 : 1000;
      } else if (pkg.isNotEmpty && pkg.contains(keyword)) {
        result += 600;
      }
    }

    // 多关键词全部命中奖励
    if (_keywords.length > 1 && matchedCount == _keywords.length) {
      result += 5000;
    }

    // 如果没有任何关键词命中且未命中完整短语/包名，得分为 0
    if (result == 0) return 0;

    // 5. 蹭热度词降权（若用户搜索词本身不包含该词，则扣分）
    for (final spam in _spamKeywords) {
      if (!rawQuery.contains(spam) && _containsWordBoundary(title, spam)) {
        result -= 6000;
      }
    }

    // 6. 严重标题堆砌惩罚（标题长度严重超出 query 且过长）
    if (title.length > 30 && title.length > rawQuery.length * 2) {
      final excess = (title.length - 30).clamp(0, 40);
      result -= excess * 50; // 最多惩罚 2000 分
    }

    return result;
  }

  int compare(
    AppListing left,
    AppListing right, {
    int Function(AppListing left, AppListing right)? tieBreaker,
  }) {
    final leftScore = score(left);
    final rightScore = score(right);
    final scoreOrder = rightScore.compareTo(leftScore);
    if (scoreOrder != 0) return scoreOrder;

    if (tieBreaker != null) {
      final tieOrder = tieBreaker(left, right);
      if (tieOrder != 0) return tieOrder;
    }

    final leftDiff = (left.name.length - rawQuery.length).abs();
    final rightDiff = (right.name.length - rawQuery.length).abs();
    final diffOrder = leftDiff.compareTo(rightDiff);
    if (diffOrder != 0) return diffOrder;

    return left.id.compareTo(right.id);
  }
}

List<AppListing> _rankSearchResults(
  String query,
  List<List<AppListing>> batches,
) {
  final ranker = SearchResultRanker(query);
  final orderMap = <AppListing, int>{};
  final allApps = <AppListing>[];
  var order = 0;

  for (final batch in batches) {
    for (final app in batch) {
      allApps.add(app);
      orderMap[app] = order;
      order += 1;
    }
  }

  allApps.sort((left, right) {
    return ranker.compare(
      left,
      right,
      tieBreaker: (l, r) => (orderMap[l] ?? 0).compareTo(orderMap[r] ?? 0),
    );
  });
  return allApps;
}

class SourceRegistry {
  SourceRegistry({
    List<ApkSourceScript> scripts = const [],
    int maxConcurrentOperations = SourceConcurrencySettings.defaultHttpRequests,
  }) : scripts = [...scripts],
       _scriptsById = {for (final script in scripts) script.id: script},
       _operations = AdjustableSemaphore(maxConcurrentOperations);
  final List<ApkSourceScript> scripts;
  final Map<String, ApkSourceScript> _scriptsById;
  final Map<String, String> lastErrors = {};
  final AdjustableSemaphore _operations;

  int get maxConcurrentOperations => _operations.limit;

  set maxConcurrentOperations(int value) => _operations.limit = value;

  void replace(ApkSourceScript script) {
    final index = scripts.indexWhere((item) => item.id == script.id);
    if (index == -1) {
      scripts.add(script);
    } else {
      final previous = scripts[index];
      scripts[index] = script;
      previous.dispose();
    }
    _scriptsById[script.id] = script;
  }

  Future<void> remove(String id) async {
    final index = scripts.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final script = scripts.removeAt(index);
    _scriptsById.remove(id);
    await script.dispose();
  }

  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
    Set<String>? enabledSourceIds,
    void Function(ApkSourceScript source, List<AppListing> results)?
    onSourceCompleted,
    SourceSearchCancellation? cancellation,
  }) async {
    final pages = await searchPage(
      query,
      host,
      page: page,
      enabledSourceIds: enabledSourceIds,
      cancellation: cancellation,
      onSourcePageCompleted: (source, result) {
        if (result.succeeded) {
          onSourceCompleted?.call(source, result.results);
        }
      },
    );
    return _rankSearchResults(
      query,
      pages.map((result) => result.results).toList(growable: false),
    );
  }

  Future<List<SourceSearchPage>> searchPage(
    String query,
    SourceHostApi host, {
    int page = 1,
    Set<String>? enabledSourceIds,
    bool clearErrors = true,
    SourceSearchCancellation? cancellation,
    void Function(ApkSourceScript source, SourceSearchPage result)?
    onSourcePageCompleted,
  }) async {
    if (page < 1) throw ArgumentError.value(page, 'page', '必须大于 0');
    if (clearErrors) lastErrors.clear();
    final selectedScripts = scripts
        .where(
          (script) =>
              enabledSourceIds == null || enabledSourceIds.contains(script.id),
        )
        .toList(growable: false);

    // All selected sources request the same page concurrently. A source that
    // has ended can be removed from enabledSourceIds by the caller before the
    // next request.
    return Future.wait(
      selectedScripts.map(
        (script) => _operations.withPermit(() async {
          if (cancellation?.isCancelled == true) {
            return SourceSearchPage(
              sourceId: script.id,
              sourceName: script.name,
              page: page,
              results: const [],
            );
          }
          try {
            final sourceResults = await script.search(query, host, page: page);
            final result = SourceSearchPage(
              sourceId: script.id,
              sourceName: script.name,
              page: page,
              results: sourceResults,
            );
            if (cancellation?.isCancelled != true) {
              onSourcePageCompleted?.call(script, result);
            }
            return result;
          } catch (error) {
            final message = error.toString();
            lastErrors[script.name] = message;
            final result = SourceSearchPage(
              sourceId: script.id,
              sourceName: script.name,
              page: page,
              results: const [],
              error: message,
            );
            if (cancellation?.isCancelled != true) {
              onSourcePageCompleted?.call(script, result);
            }
            return result;
          }
        }),
      ),
    );
  }

  Future<void> loadDetails(
    AppListing app,
    SourceHostApi host, {
    required void Function(AppDetailsProgress progress) onProgress,
  }) async {
    final script = scriptFor(app.sourceId);
    final SourceDetailProgressScript? detailScript =
        script is SourceDetailProgressScript
        ? script as SourceDetailProgressScript
        : null;
    if (detailScript == null || !detailScript.supportsDetailProgress) {
      final details = await script.details(app.id, host);
      final downloads = details.downloads
          .map(
            (file) => SourceDownloadProgress(
              candidate: SourceDownloadCandidate(
                label: file.label,
                url: file.url,
                size: file.size,
                headers: file.headers,
              ),
              files: [file],
            ),
          )
          .toList(growable: false);
      final result = AppDetailsProgress(
        details: details,
        downloads: downloads,
        phase: DetailLoadPhase.complete,
      );
      onProgress(result);
      return;
    }

    final metadata = await detailScript.detailsMetadata(app.id, host);
    final states = metadata.downloads
        .map((candidate) => SourceDownloadProgress(candidate: candidate))
        .toList();
    void publish(DetailLoadPhase phase, {String? error}) {
      onProgress(
        AppDetailsProgress(
          details: metadata.details,
          downloads: List.unmodifiable(states),
          phase: phase,
          error: error,
        ),
      );
    }

    publish(DetailLoadPhase.resolvingDownloads);
    await detailScript.resolveDownloads(
      metadata.downloads,
      host,
      onProgress: (index, files, error) {
        if (index < 0 || index >= states.length) return;
        states[index] = SourceDownloadProgress(
          candidate: states[index].candidate,
          files: files,
          error: error,
        );
        publish(DetailLoadPhase.resolvingDownloads);
      },
    );
    final finalFiles = states
        .where((item) => item.files != null)
        .expand((item) => item.files!)
        .toList(growable: false);
    final result = AppDetailsProgress(
      details: metadata.details.copyWith(downloads: finalFiles),
      downloads: List.unmodifiable(states),
      phase: DetailLoadPhase.complete,
    );
    onProgress(result);
  }

  Future<AppDetails> details(AppListing app, SourceHostApi host) {
    final script = scriptFor(app.sourceId);
    return script.details(app.id, host);
  }

  Future<List<AppListing>> lookupByPackageName(
    String packageName,
    SourceHostApi host, {
    Set<String>? enabledSourceIds,
  }) async {
    final normalized = packageName.trim();
    if (normalized.isEmpty) return const [];
    lastErrors.clear();
    final selectedScripts = scripts
        .where((script) {
          if (enabledSourceIds != null &&
              !enabledSourceIds.contains(script.id)) {
            return false;
          }
          return script is SourcePackageLookupScript &&
              (script as SourcePackageLookupScript).supportsPackageLookup;
        })
        .toList(growable: false);

    final batches = await Future.wait(
      selectedScripts.map(
        (script) => _operations.withPermit(() async {
          final packageSource = script as SourcePackageLookupScript;
          try {
            final url = (await packageSource.packageLookupUrl(
              normalized,
              host,
            ))?.trim();
            if (url == null || url.isEmpty) return const <AppListing>[];
            final details = await script.details(url, host);
            return details.packageName.trim().toLowerCase() ==
                    normalized.toLowerCase()
                ? <AppListing>[details]
                : const <AppListing>[];
          } catch (error) {
            lastErrors[script.name] = error.toString();
            return const <AppListing>[];
          }
        }),
      ),
    );
    return batches.expand((batch) => batch).toList(growable: false);
  }

  ApkSourceScript scriptFor(String sourceId) =>
      _scriptsById[sourceId] ?? (throw StateError('源运行时不存在：$sourceId'));

  List<SourceDebugProject> get debugProjects => scripts
      .whereType<DebugProjectSource>()
      .expand((script) => script.debugProjects)
      .toList(growable: false);

  Future<DebugProjectResult> runDebugProject(
    SourceDebugProject project,
    String input,
    SourceHostApi host,
  ) {
    final script = scriptFor(project.sourceId);
    if (script is! DebugProjectSource) {
      throw UnsupportedError('源未声明调试项目');
    }
    return (script as DebugProjectSource).runDebugProject(project, input, host);
  }

  Future<SourceCatalog> catalog(
    SourceHostApi host, {
    Set<String>? enabledSourceIds,
  }) async {
    var result = const SourceCatalog();
    lastErrors.clear();
    for (final script in scripts) {
      if (enabledSourceIds != null && !enabledSourceIds.contains(script.id)) {
        continue;
      }
      final SourceCatalogScript? catalog = script is SourceCatalogScript
          ? script as SourceCatalogScript
          : null;
      if (catalog == null || !catalog.supportsCatalog) continue;
      try {
        result = result.merge(await catalog.catalog(host));
      } catch (error) {
        lastErrors[script.name] = error.toString();
      }
    }
    return result;
  }

  Future<SourceCatalogPage> catalogPage(
    SourceCatalogTab tab,
    SourceHostApi host, {
    int page = 1,
  }) {
    if (page < 1) throw ArgumentError.value(page, 'page', '必须大于 0');
    final script = scriptFor(tab.sourceId);
    if (script is! SourceCatalogScript) {
      throw UnsupportedError('源未声明目录接口');
    }
    final catalog = script as SourceCatalogScript;
    return catalog.catalogPage(tab.id, host, page: page);
  }

  Future<void> dispose() async {
    for (final script in scripts) {
      await script.dispose();
    }
  }
}

class DemoHostApi implements SourceHostApi {
  @override
  bool hasDownloadSession(String downloadId) => false;

  @override
  List<BrowserTabDebugInfo> get browserTabs => const [];

  @override
  bool get supportsBrowser => false;

  @override
  bool get supportsInstall => false;

  @override
  bool get supportsShizuku => false;

  @override
  Future<String> browserOpen(String url, {required SourcePolicy policy}) =>
      throw UnsupportedError('当前平台不支持隐藏浏览器');

  @override
  Future<void> browserWaitFor(String tabId, String selector) =>
      throw UnsupportedError('当前平台不支持隐藏浏览器');

  @override
  Future<String> browserWaitForUrlChange(String tabId, String previousUrl) =>
      throw UnsupportedError('当前平台不支持隐藏浏览器');

  @override
  Future<Map<String, dynamic>> browserQuery(
    String tabId,
    Map<String, dynamic> selectors,
  ) => throw UnsupportedError('当前平台不支持隐藏浏览器');

  @override
  Future<List<Map<String, dynamic>>> browserQueryAll(
    String tabId,
    String rootSelector,
    Map<String, dynamic> selectors,
  ) => throw UnsupportedError('当前平台不支持隐藏浏览器');

  @override
  Future<void> browserClose(String tabId) async {}

  @override
  BrowserTabViewHandle? browserTabView(String tabId) => null;

  @override
  void browserAdoptController(
    String tabId,
    InAppWebViewController controller,
  ) {}

  @override
  Future<String> download(
    String url, {
    Map<String, String> headers = const {},
    String? downloadId,
    String? fileName,
    required SourcePolicy policy,
    void Function(int received, int? total)? onProgress,
  }) => throw UnsupportedError('当前平台不支持文件下载');

  @override
  Future<void> pauseDownload(String downloadId) =>
      throw UnsupportedError('当前平台不支持暂停下载');

  @override
  Future<void> resumeDownload(String downloadId) =>
      throw UnsupportedError('当前平台不支持继续下载');

  @override
  Future<void> cancelDownload(String downloadId) =>
      throw UnsupportedError('当前平台不支持取消下载');

  @override
  Future<void> removeDownloadFiles(
    String downloadId, {
    String? filePath,
  }) async {}

  @override
  Future<bool> install(
    String filePath, {
    required SourcePolicy policy,
    bool userInitiated = false,
  }) async => false;

  @override
  Future<bool> canInstallPackages() async => false;

  @override
  Future<void> requestInstallPermission() async {}

  @override
  Future<ApkInstallInfo> inspectInstall(String filePath) async =>
      const ApkInstallInfo.unsupported();

  @override
  Future<bool> openInstalled(String packageName) async => false;

  @override
  void setInstallMethod(InstallMethod method) {}

  @override
  Future<ShizukuStatus> shizukuStatus() async => ShizukuStatus.unsupported;

  @override
  Future<ShizukuStatus> requestShizukuPermission() async =>
      ShizukuStatus.unsupported;

  @override
  Future<String> request(
    String url, {
    Map<String, String> headers = const {},
    required SourcePolicy policy,
  }) => throw UnsupportedError('当前平台不支持源网络请求');

  @override
  Future<List<int>> requestBytes(
    String url, {
    Map<String, String> headers = const {},
    required SourcePolicy policy,
  }) => throw UnsupportedError('当前平台不支持源网络请求');

  @override
  Future<void> dispose() async {}
}

class ApkVisionDemoScript
    implements ApkSourceScript, SourceCatalogScript, SourcePackageLookupScript {
  @override
  bool get supportsCatalog => true;
  @override
  bool get supportsPackageLookup => false;
  @override
  String get id => 'apkvision-demo';

  @override
  String get name => 'APKVision';

  @override
  SourcePolicy get policy => const SourcePolicy(
    allowedHosts: {'apkvision.org', '*.apkvision.org'},
    allowBrowser: true,
    allowDownload: true,
  );

  @override
  Future<SourceCatalog> catalog(SourceHostApi host) async => SourceCatalog(
    defaultTabId: 'recommended',
    tabs: const [
      SourceCatalogTab(
        id: 'recommended',
        name: '推荐',
        sourceId: 'apkvision-demo',
        sourceName: 'APKVision',
        paged: false,
      ),
      SourceCatalogTab(
        id: 'arcade',
        name: 'Arcade',
        sourceId: 'apkvision-demo',
        sourceName: 'APKVision',
        paged: true,
        description: '动作与街机类应用',
      ),
    ],
  );

  @override
  Future<SourceCatalogPage> catalogPage(
    String tabId,
    SourceHostApi host, {
    int page = 1,
  }) async => SourceCatalogPage(
    tabId: tabId,
    sourceId: id,
    sourceName: name,
    page: page,
    apps: page == 1 ? [_detail] : const [],
    hasMore: tabId == 'arcade' && page == 1,
  );

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async => _detail;

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    return [_detail]
        .where(
          (app) =>
              app.name.toLowerCase().contains(normalized) ||
              app.packageName.contains(normalized),
        )
        .toList();
  }

  @override
  Future<String?> packageLookupUrl(
    String packageName,
    SourceHostApi host,
  ) async => null;

  @override
  Future<void> dispose() async {}

  static const _detail = AppDetails(
    id: 'https://apkvision.org/games/arcade/minecraft-pe-apk-55409/',
    sourceId: 'apkvision-demo',
    name: 'Minecraft',
    packageName: 'com.mojang.minecraftpe',
    version: '1.26.50.24 Beta',
    size: '1000.1 MB',
    updatedAt: 'August 5, 2026',
    category: 'Arcade',
    sourceName: 'APKVision',
    iconUrl:
        'https://apkvision.org/wp-content/uploads/2020/01/minecraft-play-with-friends.png',
    summary: 'Minecraft APK free download from APKVision.',
    description: '这是一个用于验证 APKVision 搜索、详情和下载接口的测试条目。',
    screenshots: [
      'https://img.apkvision.org/minecraft-play-with-friends/minecraft-play-with-friends-1.webp',
      'https://img.apkvision.org/minecraft-play-with-friends/minecraft-play-with-friends-2.webp',
      'https://img.apkvision.org/minecraft-play-with-friends/minecraft-play-with-friends-3.webp',
      'https://img.apkvision.org/minecraft-play-with-friends/minecraft-play-with-friends-4.webp',
      'https://img.apkvision.org/minecraft-play-with-friends/minecraft-play-with-friends-5.webp',
    ],
    comments: ['请在安装前自行校验文件来源与签名。'],
    downloads: [
      SourceDownload(
        label: 'Minecraft APK v1.26.50.24 Beta',
        url:
            'https://apkvision.org/games/arcade/minecraft-pe-apk-55409/download/v1.26.50.24-beta-apk/',
        size: '1000.1 MB',
      ),
    ],
  );
}
