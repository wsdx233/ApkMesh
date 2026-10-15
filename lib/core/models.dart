enum AppThemeMode { system, light, dark }

enum DownloadMethod { internal, browser, externalDownloader }

enum InstallMethod { system, shizuku }

enum ShizukuStatus { unsupported, unavailable, denied, authorized }

class SourceConcurrencySettings {
  const SourceConcurrencySettings({
    this.httpRequests = defaultHttpRequests,
    this.webViews = defaultWebViews,
  });

  static const defaultHttpRequests = 50;
  static const defaultWebViews = 5;
  static const minHttpRequests = 1;
  static const minWebViews = 1;

  final int httpRequests;
  final int webViews;

  SourceConcurrencySettings copyWith({int? httpRequests, int? webViews}) {
    final nextHttpRequests = httpRequests ?? this.httpRequests;
    final nextWebViews = webViews ?? this.webViews;
    return SourceConcurrencySettings(
      httpRequests: nextHttpRequests < minHttpRequests
          ? minHttpRequests
          : nextHttpRequests,
      webViews: nextWebViews < minWebViews ? minWebViews : nextWebViews,
    );
  }
}

class ApkInstallInfo {
  const ApkInstallInfo({
    required this.supported,
    required this.installed,
    required this.versionMatches,
    required this.canOpen,
    this.packageName,
    this.archiveVersionName,
    this.archiveVersionCode,
    this.installedVersionName,
    this.installedVersionCode,
    this.error,
  });

  const ApkInstallInfo.unsupported()
    : supported = false,
      installed = false,
      versionMatches = false,
      canOpen = false,
      packageName = null,
      archiveVersionName = null,
      archiveVersionCode = null,
      installedVersionName = null,
      installedVersionCode = null,
      error = null;

  final bool supported;
  final bool installed;
  final bool versionMatches;
  final bool canOpen;
  final String? packageName;
  final String? archiveVersionName;
  final int? archiveVersionCode;
  final String? installedVersionName;
  final int? installedVersionCode;
  final String? error;
}

class InstalledAppInfo {
  const InstalledAppInfo({
    required this.packageName,
    this.versionName,
    this.versionCode,
  });

  final String packageName;
  final String? versionName;
  final int? versionCode;

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'versionName': versionName,
    'versionCode': versionCode,
  };

  factory InstalledAppInfo.fromJson(Map<String, dynamic> json) {
    final packageName = (json['packageName'] ?? '').toString().trim();
    if (packageName.isEmpty) {
      throw const FormatException('已安装应用包名为空');
    }
    return InstalledAppInfo(
      packageName: packageName,
      versionName: _nullableJsonString(json['versionName']),
      versionCode: _jsonInt(json['versionCode']),
    );
  }
}

enum SourceStatus { enabled, disabled, error }

class ApkSource {
  const ApkSource({
    required this.id,
    required this.name,
    required this.homepage,
    required this.version,
    required this.description,
    required this.status,
    required this.builtIn,
    this.homeSource = false,
    this.supportsPackageLookup = false,
    this.lastSync,
  });

  final String id;
  final String name;
  final String homepage;
  final String version;
  final String description;
  final SourceStatus status;
  final bool builtIn;
  final bool homeSource;
  final bool supportsPackageLookup;
  final DateTime? lastSync;

  ApkSource copyWith({
    SourceStatus? status,
    bool? homeSource,
    bool? supportsPackageLookup,
    DateTime? lastSync,
  }) => ApkSource(
    id: id,
    name: name,
    homepage: homepage,
    version: version,
    description: description,
    status: status ?? this.status,
    builtIn: builtIn,
    homeSource: homeSource ?? this.homeSource,
    supportsPackageLookup: supportsPackageLookup ?? this.supportsPackageLookup,
    lastSync: lastSync ?? this.lastSync,
  );
}

class SourceImportResult {
  const SourceImportResult({required this.imported, required this.failures});

  final List<ApkSource> imported;
  final Map<String, String> failures;
}

class SourceCatalogTab {
  const SourceCatalogTab({
    required this.id,
    required this.name,
    required this.sourceId,
    required this.sourceName,
    required this.paged,
    this.description = '',
  });

  final String id;
  final String name;
  final String sourceId;
  final String sourceName;
  final bool paged;
  final String description;
}

class SourceCatalog {
  const SourceCatalog({this.tabs = const [], this.defaultTabId});

  final List<SourceCatalogTab> tabs;
  final String? defaultTabId;

  SourceCatalog merge(SourceCatalog other) => SourceCatalog(
    tabs: [...tabs, ...other.tabs],
    defaultTabId: defaultTabId ?? other.defaultTabId,
  );
}

class SourceCatalogPage {
  const SourceCatalogPage({
    required this.tabId,
    required this.sourceId,
    required this.sourceName,
    required this.page,
    required this.apps,
    required this.hasMore,
  });

  final String tabId;
  final String sourceId;
  final String sourceName;
  final int page;
  final List<AppListing> apps;
  final bool hasMore;
}

class SourceTestResult {
  const SourceTestResult({
    required this.sourceId,
    required this.sourceName,
    required this.resultCount,
    this.error,
  });

  final String sourceId;
  final String sourceName;
  final int resultCount;
  final String? error;

  bool get succeeded => error == null;
}

class SourceSearchPage {
  const SourceSearchPage({
    required this.sourceId,
    required this.sourceName,
    required this.page,
    required this.results,
    this.error,
  });

  final String sourceId;
  final String sourceName;
  final int page;
  final List<AppListing> results;
  final String? error;

  bool get succeeded => error == null;
}

class AppListing {
  const AppListing({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.packageName,
    required this.version,
    required this.size,
    required this.updatedAt,
    required this.category,
    required this.sourceName,
    required this.iconUrl,
    this.description = '',
    this.rating = '',
    this.author = '',
  });

  final String id;
  final String sourceId;
  final String name;
  final String packageName;
  final String version;
  final String size;
  final String updatedAt;
  final String category;
  final String sourceName;
  final String iconUrl;
  final String description;
  final String rating;
  final String author;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'name': name,
    'packageName': packageName,
    'version': version,
    'size': size,
    'updatedAt': updatedAt,
    'category': category,
    'sourceName': sourceName,
    'iconUrl': iconUrl,
    'description': description,
    'rating': rating,
    'author': author,
  };

  factory AppListing.fromJson(Map<String, dynamic> json) => AppListing(
    id: _requiredJsonString(json, 'id'),
    sourceId: _requiredJsonString(json, 'sourceId'),
    name: _requiredJsonString(json, 'name'),
    packageName: (json['packageName'] ?? '').toString(),
    version: (json['version'] ?? '').toString(),
    size: (json['size'] ?? '').toString(),
    updatedAt: (json['updatedAt'] ?? '').toString(),
    category: (json['category'] ?? '').toString(),
    sourceName: (json['sourceName'] ?? '').toString(),
    iconUrl: (json['iconUrl'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    rating: (json['rating'] ?? '').toString(),
    author: (json['author'] ?? '').toString(),
  );
}

enum InstalledAppUpdateStatus {
  upToDate,
  available,
  notInstalled,
  notFound,
  failed,
}

class InstalledAppUpdateRecord {
  const InstalledAppUpdateRecord({
    required this.key,
    required this.sourceId,
    required this.appId,
    required this.status,
    required this.checkedAt,
    this.packageName = '',
    this.installed,
    this.latest,
    this.error,
    this.nextRetryAt,
  });

  final String key;
  final String sourceId;
  final String appId;
  final String packageName;
  final InstalledAppUpdateStatus status;
  final InstalledAppInfo? installed;
  final AppListing? latest;
  final DateTime checkedAt;
  final String? error;
  final DateTime? nextRetryAt;

  bool get isAvailable =>
      status == InstalledAppUpdateStatus.available && latest != null;

  Map<String, dynamic> toJson() => {
    'key': key,
    'sourceId': sourceId,
    'appId': appId,
    'packageName': packageName,
    'status': status.name,
    'installed': installed?.toJson(),
    'latest': latest?.toJson(),
    'checkedAt': checkedAt.toIso8601String(),
    'error': error,
    'nextRetryAt': nextRetryAt?.toIso8601String(),
  };

  factory InstalledAppUpdateRecord.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'];
    final status = InstalledAppUpdateStatus.values
        .cast<InstalledAppUpdateStatus?>()
        .firstWhere((value) => value?.name == statusName, orElse: () => null);
    final checkedAt = DateTime.tryParse((json['checkedAt'] ?? '').toString());
    if (status == null || checkedAt == null) {
      throw const FormatException('应用更新缓存状态无效');
    }
    final rawInstalled = json['installed'];
    return InstalledAppUpdateRecord(
      key: _requiredJsonString(json, 'key'),
      sourceId: _requiredJsonString(json, 'sourceId'),
      appId: _requiredJsonString(json, 'appId'),
      packageName: (json['packageName'] ?? '').toString(),
      status: status,
      installed: rawInstalled is Map
          ? InstalledAppInfo.fromJson(Map<String, dynamic>.from(rawInstalled))
          : null,
      latest: _optionalAppListing(json['latest']),
      checkedAt: checkedAt,
      error: _nullableJsonString(json['error']),
      nextRetryAt: json['nextRetryAt'] == null
          ? null
          : DateTime.tryParse(json['nextRetryAt'].toString()),
    );
  }
}

class SourceDebugProject {
  const SourceDebugProject({
    required this.sourceId,
    required this.sourceName,
    required this.id,
    required this.name,
    required this.description,
    required this.inputLabel,
    required this.placeholder,
    this.defaultInput = '',
  });

  final String sourceId;
  final String sourceName;
  final String id;
  final String name;
  final String description;
  final String inputLabel;
  final String placeholder;
  final String defaultInput;

  String get key => '$sourceId:$id';
}

class DebugProjectResult {
  const DebugProjectResult({
    required this.projectId,
    required this.sourceId,
    required this.title,
    required this.summary,
    required this.data,
  });

  final String projectId;
  final String sourceId;
  final String title;
  final String summary;
  final dynamic data;
}

class SourceDownloadCandidate {
  const SourceDownloadCandidate({
    required this.label,
    required this.url,
    required this.size,
    this.headers = const {},
  });

  final String label;
  final String url;
  final String size;
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
    'size': size,
    'headers': headers,
  };
}

class SourceDetailsMetadata {
  const SourceDetailsMetadata({required this.details, required this.downloads});

  final AppDetails details;
  final List<SourceDownloadCandidate> downloads;
}

class SourceDownloadProgress {
  const SourceDownloadProgress({
    required this.candidate,
    this.files,
    this.error,
  });

  final SourceDownloadCandidate candidate;
  final List<SourceDownload>? files;
  final String? error;

  bool get completed => files != null || error != null;
  bool get resolving => !completed;
}

enum DetailLoadPhase { loadingDetails, resolvingDownloads, complete }

class AppDetailsProgress {
  const AppDetailsProgress({
    required this.details,
    required this.downloads,
    required this.phase,
    this.error,
  });

  final AppDetails details;
  final List<SourceDownloadProgress> downloads;
  final DetailLoadPhase phase;
  final String? error;

  int get totalDownloads => downloads.length;
  int get completedDownloads =>
      downloads.where((download) => download.completed).length;
  bool get downloadsComplete => phase == DetailLoadPhase.complete;
}

class AppDownloadResult {
  const AppDownloadResult({
    required this.app,
    required this.startedFiles,
    this.error,
  });

  final AppListing app;
  final int startedFiles;
  final String? error;

  bool get hasStarted => startedFiles > 0;
}

class AppBatchDownloadResult {
  const AppBatchDownloadResult(this.results);

  final List<AppDownloadResult> results;

  int get startedFiles =>
      results.fold(0, (total, result) => total + result.startedFiles);

  int get successfulApps => results.where((result) => result.hasStarted).length;

  int get appsWithErrors =>
      results.where((result) => result.error != null).length;

  List<AppDownloadResult> get failedApps =>
      results.where((result) => !result.hasStarted).toList(growable: false);
}

class SourceDownload {
  const SourceDownload({
    required this.label,
    required this.url,
    required this.size,
    this.headers = const {},
  });
  final String label;
  final String url;
  final String size;
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
    'size': size,
    'headers': Map.fromEntries(
      headers.entries.where(
        (entry) => !const {
          'authorization',
          'cookie',
          'proxy-authorization',
          'set-cookie',
        }.contains(entry.key.toLowerCase()),
      ),
    ),
  };

  factory SourceDownload.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    return SourceDownload(
      label: _requiredJsonString(json, 'label'),
      url: _requiredJsonString(json, 'url'),
      size: (json['size'] ?? '').toString(),
      headers: Map<String, String>.unmodifiable(headers),
    );
  }
}

String _requiredJsonString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('下载任务字段无效：$key');
  }
  return value;
}

String? _nullableJsonString(dynamic value) => value is String ? value : null;

int? _jsonInt(dynamic value) {
  if (value is int) return value;
  return value == null ? null : int.tryParse(value.toString());
}

DateTime _requiredJsonDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse((json[key] ?? '').toString());
  if (value == null) throw FormatException('下载任务时间字段无效：$key');
  return value;
}

AppListing? _optionalAppListing(dynamic value) {
  if (value is! Map) return null;
  try {
    return AppListing.fromJson(Map<String, dynamic>.from(value));
  } on Object {
    return null;
  }
}

class DownloadPolicySnapshot {
  const DownloadPolicySnapshot({
    required this.allowedHosts,
    this.allowInstall = false,
  });

  final List<String> allowedHosts;
  final bool allowInstall;

  Map<String, dynamic> toJson() => {
    'allowedHosts': allowedHosts,
    'allowInstall': allowInstall,
  };

  factory DownloadPolicySnapshot.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['allowedHosts'];
    if (rawHosts is! List || rawHosts.any((host) => host is! String)) {
      throw const FormatException('下载权限字段无效');
    }
    final hosts = rawHosts.cast<String>().where((host) => host.isNotEmpty);
    if (hosts.isEmpty) throw const FormatException('下载权限主机为空');
    return DownloadPolicySnapshot(
      allowedHosts: List<String>.unmodifiable(hosts),
      allowInstall: json['allowInstall'] == true,
    );
  }
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => '下载已取消';
}

enum DownloadStatus { downloading, paused, completed, failed, canceled }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.file,
    required this.sourceId,
    required this.status,
    required this.startedAt,
    this.received = 0,
    this.total,
    this.speedBytesPerSecond,
    this.policy,
    this.filePath,
    this.error,
    this.completedAt,
    this.app,
  });

  static const _notProvided = Object();

  final String id;
  final SourceDownload file;
  final String sourceId;
  final DownloadStatus status;
  final DateTime startedAt;
  final int received;
  final int? total;
  final int? speedBytesPerSecond;
  final DownloadPolicySnapshot? policy;
  final String? filePath;
  final String? error;
  final DateTime? completedAt;
  final AppListing? app;

  double? get progress =>
      total != null && total! > 0 ? (received / total!).clamp(0.0, 1.0) : null;

  Duration? get estimatedRemaining {
    final totalBytes = total;
    final speed = speedBytesPerSecond;
    if (totalBytes == null ||
        speed == null ||
        speed <= 0 ||
        received >= totalBytes) {
      return null;
    }
    final remaining = totalBytes - received;
    final milliseconds = (remaining * 1000 / speed).ceil();
    return Duration(milliseconds: milliseconds);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'file': file.toJson(),
    'sourceId': sourceId,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'received': received,
    'total': total,
    'speedBytesPerSecond': speedBytesPerSecond,
    'policy': policy?.toJson(),
    'filePath': filePath,
    'error': error,
    'completedAt': completedAt?.toIso8601String(),
    'app': app?.toJson(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final rawFile = json['file'];
    if (rawFile is! Map) throw const FormatException('下载任务文件字段无效');
    final statusName = json['status'];
    final status = DownloadStatus.values.cast<DownloadStatus?>().firstWhere(
      (value) => value?.name == statusName,
      orElse: () => null,
    );
    if (status == null) throw const FormatException('下载任务状态无效');
    return DownloadTask(
      id: _requiredJsonString(json, 'id'),
      file: SourceDownload.fromJson(Map<String, dynamic>.from(rawFile)),
      sourceId: _requiredJsonString(json, 'sourceId'),
      status: status,
      startedAt: _requiredJsonDateTime(json, 'startedAt'),
      received: (_jsonInt(json['received']) ?? 0).clamp(0, 1 << 62),
      total: _jsonInt(json['total']),
      speedBytesPerSecond: _jsonInt(json['speedBytesPerSecond']),
      policy: json['policy'] is Map
          ? DownloadPolicySnapshot.fromJson(
              Map<String, dynamic>.from(json['policy'] as Map),
            )
          : null,
      filePath: _nullableJsonString(json['filePath']),
      error: _nullableJsonString(json['error']),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
      app: _optionalAppListing(json['app']),
    );
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    DateTime? startedAt,
    int? received,
    Object? total = _notProvided,
    Object? speedBytesPerSecond = _notProvided,
    Object? policy = _notProvided,
    Object? filePath = _notProvided,
    Object? error = _notProvided,
    Object? completedAt = _notProvided,
    Object? app = _notProvided,
  }) => DownloadTask(
    id: id,
    file: file,
    sourceId: sourceId,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    received: received ?? this.received,
    total: identical(total, _notProvided) ? this.total : total as int?,
    speedBytesPerSecond: identical(speedBytesPerSecond, _notProvided)
        ? this.speedBytesPerSecond
        : speedBytesPerSecond as int?,
    policy: identical(policy, _notProvided)
        ? this.policy
        : policy as DownloadPolicySnapshot?,
    filePath: identical(filePath, _notProvided)
        ? this.filePath
        : filePath as String?,
    error: identical(error, _notProvided) ? this.error : error as String?,
    completedAt: identical(completedAt, _notProvided)
        ? this.completedAt
        : completedAt as DateTime?,
    app: identical(app, _notProvided) ? this.app : app as AppListing?,
  );
}

class AppDetails extends AppListing {
  const AppDetails({
    required super.id,
    required super.sourceId,
    required super.name,
    required super.packageName,
    required super.version,
    required super.size,
    required super.updatedAt,
    required super.category,
    required super.sourceName,
    required super.iconUrl,
    required this.summary,
    super.description = '',
    super.rating = '',
    super.author = '',
    required this.screenshots,
    required this.comments,
    required this.downloads,
  });

  final String summary;
  final List<String> screenshots;
  final List<String> comments;
  final List<SourceDownload> downloads;

  AppDetails copyWith({List<SourceDownload>? downloads}) => AppDetails(
    id: id,
    sourceId: sourceId,
    name: name,
    packageName: packageName,
    version: version,
    size: size,
    updatedAt: updatedAt,
    category: category,
    sourceName: sourceName,
    iconUrl: iconUrl,
    summary: summary,
    description: description,
    rating: rating,
    author: author,
    screenshots: screenshots,
    comments: comments,
    downloads: downloads ?? this.downloads,
  );
}
