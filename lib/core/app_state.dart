import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'app_language.dart';
import 'debug_log.dart';
import 'download_notifications.dart';
import 'download_store.dart';
import 'external_download_launcher.dart' as external_download;
import 'host_factory.dart';
import 'models.dart';
import 'quickjs_source.dart';
import 'source_import.dart';
import 'source_runtime.dart';
import 'translation_service.dart';

String _newTranslationDeviceId() =>
    'apkmesh-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(0x100000000)}';

class AppState extends ChangeNotifier {
  AppState({SourceHostApi? host}) : _hostOverride = host {
    _sources = [
      ApkSource(
        id: 'apkvision-demo',
        name: 'APKVision',
        homepage: 'apkvision.org',
        version: '1.0.0',
        description: strings.demoSourceDescription,
        status: SourceStatus.enabled,
        builtIn: true,
        homeSource: true,
        lastSync: DateTime.now(),
      ),
    ];
    _sourceView = List<ApkSource>.unmodifiable(_sources);
    _downloadNotifications = DownloadNotifications(
      onAction: _handleDownloadNotificationAction,
    );
    _settingsReady = _restoreSettings();
  }

  final SourceHostApi? _hostOverride;
  late List<ApkSource> _sources;
  late List<ApkSource> _sourceView;
  final SourceRegistry registry = SourceRegistry(
    scripts: [ApkVisionDemoScript()],
  );
  final DebugLogStore debug = DebugLogStore();
  late final SourceHostApi host =
      _hostOverride ?? createPlatformHostApi(debug: debug);
  late final DownloadNotifications _downloadNotifications;
  final Completer<void> _ready = Completer<void>();
  final DownloadStore _downloadStore = createDownloadStore();
  late final TranslationService translation = TranslationService(
    localizations: () => strings,
  );
  final List<DownloadTask> _downloads = [];
  final List<AppListing> _favorites = [];
  final List<AppListing> _history = [];
  final Map<String, ApkInstallInfo> _installInfos = {};
  final Set<String> _installStateChecks = {};
  final Set<String> _installingDownloads = {};
  final Map<String, String> _translationCache = {};
  final Set<String> _translationPending = {};
  final Set<String> _translationQueue = {};
  final Map<String, Map<String, AppDetailsProgress>> _detailsCache = {};
  Timer? _translationQueueTimer;
  TranslationSettings _translationSettings = const TranslationSettings();
  SourceConcurrencySettings _sourceConcurrency =
      const SourceConcurrencySettings();
  DownloadMethod _downloadMethod = DownloadMethod.internal;
  Set<String> _disabledSourceIds = {};
  List<String> _searchTabSourceIds = const [];
  String? _preferredHomeSourceId;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _appLanguage = AppLanguage.system;
  AppLocalizations _strings = lookupAppLocalizations(
    resolveAppLocale(PlatformDispatcher.instance.locale),
  );
  InstallMethod _installMethod = InstallMethod.system;
  ShizukuStatus _shizukuStatus = ShizukuStatus.unsupported;
  String _translationDeviceId = _newTranslationDeviceId();
  SharedPreferences? _preferences;
  late final Future<void> _settingsReady;
  final Set<String> _resumeAfterInitialize = {};
  final Map<String, int> _pendingDownloadBytes = {};
  final Map<String, int?> _pendingDownloadTotals = {};
  final Map<String, Timer> _downloadProgressTimers = {};
  final Map<String, ({int received, DateTime timestamp})>
  _downloadProgressSamples = {};
  Future<void> _downloadPersistenceQueue = Future.value();
  Timer? _downloadPersistenceTimer;
  int _downloadSequence = 0;
  bool _isDisposing = false;
  bool _sourceRuntimeReady = false;
  String? _runtimeError;
  static const _historyLimit = 100;
  static const _favoritesKey = 'library.favorites';
  static const _historyKey = 'library.history';

  List<ApkSource> get sources => _sourceView;
  List<DownloadTask> get downloads => List.unmodifiable(_downloads);
  List<AppListing> get favorites => List.unmodifiable(_favorites);
  List<AppListing> get history => List.unmodifiable(_history);
  bool get sourceRuntimeReady => _sourceRuntimeReady;
  Future<void> get ready => _ready.future;
  String? get runtimeError => _runtimeError;
  Map<String, String> get sourceErrors => Map.unmodifiable(registry.lastErrors);
  bool get hasEnabledSource =>
      _sources.any((source) => source.status == SourceStatus.enabled);
  String? get homeSourceId {
    for (final source in _sources) {
      if (source.homeSource && source.status == SourceStatus.enabled) {
        return source.id;
      }
    }
    return null;
  }

  bool isFavorite(AppListing app) {
    final key = _appKey(app);
    return key != null && _favorites.any((item) => _appKey(item) == key);
  }

  void toggleFavorite(AppListing app) {
    final key = _appKey(app);
    if (key == null) return;
    final index = _favorites.indexWhere((item) => _appKey(item) == key);
    if (index == -1) {
      _favorites.insert(0, app);
    } else {
      _favorites.removeAt(index);
    }
    notifyListeners();
    unawaited(_persistSettings());
  }

  int favoriteApps(Iterable<AppListing> apps) {
    final existing = _favorites.map(_appKey).whereType<String>().toSet();
    var added = 0;
    for (final app in apps) {
      final key = _appKey(app);
      if (key == null || !existing.add(key)) continue;
      _favorites.insert(0, app);
      added += 1;
    }
    if (added > 0) {
      notifyListeners();
      unawaited(_persistSettings());
    }
    return added;
  }

  void clearFavorites() {
    if (_favorites.isEmpty) return;
    _favorites.clear();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void recordHistory(AppListing app) {
    final key = _appKey(app);
    if (key == null) return;
    final existingIndex = _history.indexWhere((item) => _appKey(item) == key);
    final changed =
        existingIndex != 0 ||
        existingIndex == -1 ||
        !_sameListing(_history.first, app);
    if (existingIndex != -1) _history.removeAt(existingIndex);
    _history.insert(0, app);
    if (_history.length > _historyLimit) {
      _history.removeRange(_historyLimit, _history.length);
    }
    if (changed) {
      notifyListeners();
      unawaited(_persistSettings());
    }
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
    unawaited(_persistSettings());
  }

  String? _appKey(AppListing app) {
    final sourceId = app.sourceId.trim();
    final id = app.id.trim();
    if (sourceId.isEmpty || id.isEmpty) return null;
    return '$sourceId\u0000$id';
  }

  bool _sameListing(AppListing left, AppListing right) =>
      left.toJson().toString() == right.toJson().toString();

  List<String> _encodeAppList(Iterable<AppListing> apps) =>
      apps.map((app) => jsonEncode(app.toJson())).toList(growable: false);

  List<AppListing> _decodeAppList(List<String>? values) {
    if (values == null) return [];
    final result = <AppListing>[];
    final seen = <String>{};
    for (final value in values) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) continue;
        final app = AppListing.fromJson(Map<String, dynamic>.from(decoded));
        final key = _appKey(app);
        if (key != null && seen.add(key)) result.add(app);
      } on Object {
        // Ignore entries from older or partially written preferences.
      }
    }
    return result;
  }

  List<SourceDebugProject> get debugProjects => registry.debugProjects;
  TranslationSettings get translationSettings => _translationSettings;
  SourceConcurrencySettings get sourceConcurrency => _sourceConcurrency;
  List<String> get searchTabSourceIds => _searchTabSourceIds;
  DownloadMethod get downloadMethod => _downloadMethod;
  bool get supportsExternalDownloader =>
      external_download.supportsExternalDownloader;
  AppThemeMode get themeMode => _themeMode;
  AppLanguage get appLanguage => _appLanguage;
  AppLocalizations get strings => _strings;

  Future<void> setAppLanguage(AppLanguage language) async {
    await _settingsReady;
    if (_isDisposing || _appLanguage == language) return;
    _appLanguage = language;
    _refreshAppLocale();
    notifyListeners();
    await _persistSettings();
  }

  void updateSystemLocale() {
    if (_isDisposing || _appLanguage != AppLanguage.system) return;
    _refreshAppLocale();
    notifyListeners();
  }

  void _refreshAppLocale() {
    final locale = resolveAppLocale(
      _appLanguage.locale ?? PlatformDispatcher.instance.locale,
    );
    _strings = lookupAppLocalizations(locale);
    unawaited(syncNativeAppLocale(locale));
  }

  InstallMethod get installMethod => _installMethod;
  bool get useShizukuInstaller => _installMethod == InstallMethod.shizuku;
  ShizukuStatus get shizukuStatus => _shizukuStatus;
  ApkInstallInfo? installInfoFor(String downloadId) =>
      _installInfos[downloadId];
  bool isInstallingDownload(String downloadId) =>
      _installingDownloads.contains(downloadId);

  String? translatedText(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return _translationCache[_translationKey(value, _translationSettings)];
  }

  Future<String> translateToEnglish(String text) async {
    final value = text.trim();
    if (value.isEmpty) return '';
    await _settingsReady;
    if (_isDisposing) throw StateError(strings.translationClosed);
    final settings = _translationSettings.copyWith(targetLanguage: 'en');
    final results = await translation.translate(
      [value],
      settings: settings,
      deviceId: _translationDeviceId,
    );
    if (results.isEmpty || results.first.trim().isEmpty) {
      throw FormatException(strings.translationEmpty);
    }
    return results.first.trim();
  }

  bool isTranslationLoading(String text) {
    final value = text.trim();
    return value.isNotEmpty &&
        _translationPending.contains(
          _translationKey(value, _translationSettings),
        );
  }

  void ensureTranslations(Iterable<String> texts) {
    if (_isDisposing) return;
    for (final rawText in texts) {
      final text = rawText.trim();
      if (text.isEmpty) continue;
      final key = _translationKey(text, _translationSettings);
      if (_translationCache.containsKey(key) ||
          _translationPending.contains(key)) {
        continue;
      }
      _translationQueue.add(text);
    }
    if (_translationQueue.isNotEmpty && _translationQueueTimer == null) {
      _translationQueueTimer = Timer(
        const Duration(milliseconds: 50),
        _flushTranslationQueue,
      );
    }
  }

  void _flushTranslationQueue() {
    _translationQueueTimer = null;
    if (_translationQueue.isEmpty || _isDisposing) return;
    final texts = _translationQueue.toList(growable: false);
    _translationQueue.clear();
    final settings = _translationSettings;
    final keys = texts
        .map((text) => _translationKey(text, settings))
        .toList(growable: false);
    _translationPending.addAll(keys);
    unawaited(_runTranslations(texts, settings, keys));
  }

  Future<void> _runTranslations(
    List<String> texts,
    TranslationSettings settings,
    List<String> keys,
  ) async {
    try {
      final results = await translation.translate(
        texts,
        settings: settings,
        deviceId: _translationDeviceId,
      );
      for (var index = 0; index < texts.length; index++) {
        final result = results[index].trim();
        if (result.isNotEmpty) _translationCache[keys[index]] = result;
      }
    } catch (error) {
      if (!_isDisposing) {
        debug.add(
          strings.providerTranslationFailed(
            (settings.provider.label(strings)).toString(),
            (error).toString(),
          ),
          level: DebugLogLevel.warning,
          category: 'Translation',
        );
      }
    } finally {
      _translationPending.removeAll(keys);
      if (!_isDisposing) notifyListeners();
    }
  }

  String _translationKey(String text, TranslationSettings settings) =>
      '${settings.provider.name}|${translationLanguageCode(settings.targetLanguage, settings.provider)}|$text';

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setDownloadMethod(DownloadMethod method) {
    if (_downloadMethod == method) return;
    _downloadMethod = method;
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setSearchTabSourceIds(Iterable<String> ids) {
    final next = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (id.isNotEmpty && seen.add(id)) next.add(id);
    }
    if (listEquals(_searchTabSourceIds, next)) return;
    _searchTabSourceIds = List.unmodifiable(next);
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setTranslationProvider(TranslationProvider provider) {
    if (_translationSettings.provider == provider) return;
    _translationSettings = _translationSettings.copyWith(provider: provider);
    _translationCache.clear();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setTranslationLanguage(String language) {
    if (_translationSettings.targetLanguage == language) return;
    _translationSettings = _translationSettings.copyWith(
      targetLanguage: language,
    );
    _translationCache.clear();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setAutoTranslate(bool enabled) {
    if (_translationSettings.autoTranslate == enabled) return;
    _translationSettings = _translationSettings.copyWith(
      autoTranslate: enabled,
    );
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setGooglePublicKey(String value) {
    final key = value.trim();
    if (_translationSettings.googlePublicKey == key) return;
    _translationSettings = _translationSettings.copyWith(googlePublicKey: key);
    _translationCache.removeWhere(
      (cacheKey, _) => cacheKey.startsWith('google|'),
    );
    notifyListeners();
    unawaited(_persistSettings());
  }

  Future<void> refreshShizukuStatus() async {
    try {
      final status = await host.shizukuStatus();
      if (_isDisposing || _shizukuStatus == status) return;
      _shizukuStatus = status;
      notifyListeners();
    } catch (error) {
      if (!_isDisposing) {
        debug.add(
          strings.shizukuStatusFailed((error).toString()),
          level: DebugLogLevel.warning,
          category: 'Install',
        );
      }
    }
  }

  Future<void> refreshInstallState(DownloadTask task) async {
    final path = task.filePath;
    if (task.status != DownloadStatus.completed || path == null) return;
    if (!_installStateChecks.add(task.id)) return;
    try {
      final info = await host.inspectInstall(path);
      final current = _downloadById(task.id);
      if (_isDisposing || current?.filePath != path) return;
      _installInfos[task.id] = info;
      notifyListeners();
    } catch (error) {
      if (!_isDisposing) {
        debug.add(
          strings.installStatusFailed(
            (task.file.label).toString(),
            (error).toString(),
          ),
          level: DebugLogLevel.warning,
          category: 'Install',
        );
      }
    } finally {
      _installStateChecks.remove(task.id);
    }
  }

  Future<void> refreshInstallStates() async {
    final completed = _downloads
        .where(
          (task) =>
              task.status == DownloadStatus.completed && task.filePath != null,
        )
        .toList(growable: false);
    for (final task in completed) {
      await refreshInstallState(task);
    }
  }

  Future<void> openInstalledTask(DownloadTask task) async {
    var info = _installInfos[task.id];
    if (info == null || !info.versionMatches) {
      await refreshInstallState(task);
      info = _installInfos[task.id];
    }
    final packageName = info?.packageName;
    if (info == null || !info.versionMatches || packageName == null) {
      throw StateError(info?.error ?? strings.appNotInstalled);
    }
    if (!await host.openInstalled(packageName)) {
      throw StateError(strings.installedAppOpenFailed);
    }
  }

  Future<bool> setUseShizukuInstaller(bool enabled) async {
    await _settingsReady;
    if (_isDisposing) return false;
    if (!enabled) {
      if (_installMethod == InstallMethod.system) return true;
      _installMethod = InstallMethod.system;
      host.setInstallMethod(_installMethod);
      notifyListeners();
      await _persistSettings();
      return true;
    }

    final status = await host.requestShizukuPermission();
    if (_isDisposing) return false;
    _shizukuStatus = status;
    if (status != ShizukuStatus.authorized) {
      notifyListeners();
      return false;
    }
    _installMethod = InstallMethod.shizuku;
    host.setInstallMethod(_installMethod);
    notifyListeners();
    await _persistSettings();
    return true;
  }

  Future<void> _restoreSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposing) return;
      _preferences = preferences;
      _appLanguage = AppLanguage.fromPreference(
        preferences.getString('app.language'),
      );
      _refreshAppLocale();
      _favorites
        ..clear()
        ..addAll(_decodeAppList(preferences.getStringList(_favoritesKey)));
      _history
        ..clear()
        ..addAll(_decodeAppList(preferences.getStringList(_historyKey)));
      if (_history.length > _historyLimit) {
        _history.removeRange(_historyLimit, _history.length);
      }
      _disabledSourceIds =
          preferences.getStringList('source.disabledIds')?.toSet() ?? {};
      _searchTabSourceIds = List.unmodifiable(
        preferences.getStringList('source.searchTabIds') ?? const <String>[],
      );
      _preferredHomeSourceId = preferences.getString('source.homeId');
      _applyStoredSourcePreferences();
      final providerIndex = preferences.getInt('translation.provider') ?? 0;
      final provider =
          providerIndex >= 0 &&
              providerIndex < TranslationProvider.values.length
          ? TranslationProvider.values[providerIndex]
          : TranslationProvider.microsoft;
      final themeModeIndex =
          preferences.getInt('theme.mode') ?? AppThemeMode.system.index;
      _themeMode =
          themeModeIndex >= 0 && themeModeIndex < AppThemeMode.values.length
          ? AppThemeMode.values[themeModeIndex]
          : AppThemeMode.system;
      _downloadMethod = switch (preferences.getString('download.method')) {
        'browser' => DownloadMethod.browser,
        'externalDownloader' => DownloadMethod.externalDownloader,
        _ => DownloadMethod.internal,
      };
      _installMethod = switch (preferences.getString('install.method')) {
        'shizuku' => InstallMethod.shizuku,
        _ => InstallMethod.system,
      };
      host.setInstallMethod(_installMethod);
      _sourceConcurrency = const SourceConcurrencySettings().copyWith(
        httpRequests: preferences.getInt('source.httpConcurrency'),
        webViews: preferences.getInt('source.webViewConcurrency'),
      );
      _applySourceConcurrency();
      _translationSettings = TranslationSettings(
        provider: provider,
        targetLanguage:
            preferences.getString('translation.language') ?? 'system',
        autoTranslate: preferences.getBool('translation.auto') ?? true,
        googlePublicKey: preferences.getString('translation.googleKey') ?? '',
      );
      _translationDeviceId =
          preferences.getString('translation.deviceId') ??
          _newTranslationDeviceId();
      await preferences.setString('translation.deviceId', _translationDeviceId);
      try {
        _shizukuStatus = await host.shizukuStatus();
      } catch (error) {
        debug.add(
          strings.shizukuStatusFailed((error).toString()),
          level: DebugLogLevel.warning,
          category: 'Install',
        );
      }
      if (!_isDisposing) notifyListeners();
    } catch (error) {
      _translationDeviceId = _newTranslationDeviceId();
      if (!_isDisposing) {
        debug.add(
          strings.settingsRestoreFailed((error).toString()),
          level: DebugLogLevel.warning,
          category: 'Translation',
        );
      }
    }
  }

  Future<void> _persistSettings() async {
    await _settingsReady;
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setInt(
      'translation.provider',
      _translationSettings.provider.index,
    );
    await preferences.setString(
      'translation.language',
      _translationSettings.targetLanguage,
    );
    await preferences.setBool(
      'translation.auto',
      _translationSettings.autoTranslate,
    );
    await preferences.setString(
      'translation.googleKey',
      _translationSettings.googlePublicKey,
    );
    await preferences.setString('app.language', _appLanguage.preference);
    await preferences.setInt('theme.mode', _themeMode.index);
    await preferences.setString('download.method', _downloadMethod.name);
    await preferences.setString('install.method', _installMethod.name);
    await preferences.setInt(
      'source.httpConcurrency',
      _sourceConcurrency.httpRequests,
    );
    await preferences.setInt(
      'source.webViewConcurrency',
      _sourceConcurrency.webViews,
    );
    final disabledIds =
        _sources
            .where((source) => source.status == SourceStatus.disabled)
            .map((source) => source.id)
            .toList()
          ..sort();
    await preferences.setStringList('source.disabledIds', disabledIds);
    await preferences.setStringList('source.searchTabIds', _searchTabSourceIds);
    await preferences.setStringList(_favoritesKey, _encodeAppList(_favorites));
    await preferences.setStringList(_historyKey, _encodeAppList(_history));
    final selectedHomeSourceId = homeSourceId;
    if (selectedHomeSourceId == null) {
      await preferences.remove('source.homeId');
    } else {
      await preferences.setString('source.homeId', selectedHomeSourceId);
    }
  }

  void _refreshSourceView() {
    _sourceView = List<ApkSource>.unmodifiable(_sources);
  }

  void _applyStoredSourcePreferences() {
    _sources = _sources
        .map(
          (source) => source.copyWith(
            status: _disabledSourceIds.contains(source.id)
                ? SourceStatus.disabled
                : SourceStatus.enabled,
            homeSource: false,
          ),
        )
        .toList();
    final preferred = _preferredHomeSourceId;
    final selectedId = _sources
        .where(
          (source) =>
              source.status == SourceStatus.enabled && source.id == preferred,
        )
        .map((source) => source.id)
        .firstOrNull;
    final fallbackId =
        selectedId ??
        _sources
            .where((source) => source.status == SourceStatus.enabled)
            .map((source) => source.id)
            .firstOrNull;
    if (fallbackId != null) {
      _sources = _sources
          .map((source) => source.copyWith(homeSource: source.id == fallbackId))
          .toList();
    }
    _refreshSourceView();
  }

  void setSourceConcurrency({int? httpRequests, int? webViews}) {
    final next = _sourceConcurrency.copyWith(
      httpRequests: httpRequests,
      webViews: webViews,
    );
    if (next.httpRequests == _sourceConcurrency.httpRequests &&
        next.webViews == _sourceConcurrency.webViews) {
      return;
    }
    _sourceConcurrency = next;
    _applySourceConcurrency();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void _applySourceConcurrency() {
    registry.maxConcurrentOperations = _sourceConcurrency.httpRequests;
    setQuickJsRuntimeConcurrency(_sourceConcurrency.httpRequests);
    final currentHost = host;
    if (currentHost is SourceHostConcurrencyApi) {
      (currentHost as SourceHostConcurrencyApi).setSourceConcurrency(
        _sourceConcurrency,
      );
    }
  }

  ApkSource _sourceForScript(ApkSourceScript script, {required bool builtIn}) {
    final SourceManifestProvider? manifest = script is SourceManifestProvider
        ? script as SourceManifestProvider
        : null;
    return ApkSource(
      id: script.id,
      name: script.name,
      homepage: manifest?.homepage ?? '',
      version: manifest?.version ?? '0.0.0',
      description: manifest?.description ?? strings.builtInQuickJsSource,
      status: _disabledSourceIds.contains(script.id)
          ? SourceStatus.disabled
          : SourceStatus.enabled,
      builtIn: builtIn,
      homeSource: _preferredHomeSourceId == script.id,
      supportsPackageLookup:
          script is SourcePackageLookupScript &&
          (script as SourcePackageLookupScript).supportsPackageLookup,
      lastSync: DateTime.now(),
    );
  }

  void _registerBuiltInScript(ApkSourceScript script) {
    final source = _sourceForScript(script, builtIn: true);
    final index = _sources.indexWhere((item) => item.id == source.id);
    if (index == -1) {
      _sources = [..._sources, source];
      return;
    }

    final existing = _sources[index];
    _sources[index] = source.copyWith(
      status: _disabledSourceIds.contains(source.id)
          ? SourceStatus.disabled
          : existing.status,
      homeSource: _preferredHomeSourceId == null
          ? existing.homeSource
          : _preferredHomeSourceId == source.id,
    );
  }

  Future<void> _restoreDownloads() async {
    try {
      final restored = await _downloadStore.load();
      final ids = <String>{};
      for (final task in restored) {
        if (!ids.add(task.id)) continue;
        if (task.status == DownloadStatus.downloading) {
          _resumeAfterInitialize.add(task.id);
          _downloads.add(
            task.copyWith(
              status: DownloadStatus.paused,
              speedBytesPerSecond: null,
            ),
          );
        } else {
          _downloads.add(task);
        }
      }
      if (_downloads.isNotEmpty) notifyListeners();
      debug.add(
        strings.downloadsRestored((_downloads.length).toString()),
        category: 'Download',
      );
    } catch (error) {
      debug.add(
        strings.downloadsRestoreFailed((error).toString()),
        level: DebugLogLevel.error,
        category: 'Download',
      );
    }
  }

  void _scheduleDownloadPersistence({bool immediate = false}) {
    if (_isDisposing && !immediate) return;
    if (immediate) {
      _downloadPersistenceTimer?.cancel();
      _downloadPersistenceTimer = null;
      _persistDownloadsNow();
      return;
    }
    if (_downloadPersistenceTimer != null) return;
    _downloadPersistenceTimer = Timer(
      const Duration(milliseconds: 500),
      _persistDownloadsNow,
    );
  }

  void _persistDownloadsNow() {
    _downloadPersistenceTimer?.cancel();
    _downloadPersistenceTimer = null;
    final snapshot = List<DownloadTask>.unmodifiable(_downloads);
    _downloadPersistenceQueue = _downloadPersistenceQueue.then((_) async {
      try {
        await _downloadStore.save(snapshot);
      } catch (error) {
        debugPrint(strings.downloadsSaveFailed((error).toString()));
      }
    });
  }

  Future<void> _resumeRestoredDownloads() async {
    final ids = _resumeAfterInitialize.toList(growable: false);
    _resumeAfterInitialize.clear();
    for (final id in ids) {
      if (_isDisposing) return;
      final task = _downloadById(id);
      if (task == null) continue;
      try {
        _policyForTask(task);
      } catch (_) {
        _replaceDownload(
          task.copyWith(
            status: DownloadStatus.failed,
            error: strings.downloadSourceMissing,
            completedAt: DateTime.now(),
          ),
        );
        continue;
      }
      _replaceDownload(
        task.copyWith(
          status: DownloadStatus.downloading,
          speedBytesPerSecond: null,
          error: null,
          completedAt: null,
        ),
      );
      unawaited(_runDownload(id));
    }
  }

  Future<void> initialize() async {
    unawaited(_settingsReady);
    await _restoreDownloads();
    unawaited(refreshInstallStates());
    debug.add(strings.scanningSources, category: 'App');
    var loadedCount = 0;
    try {
      final assetPaths = await discoverSourceAssets();
      debug.add(
        strings.bundledSourcesFound((assetPaths.length).toString()),
        category: 'App',
      );
      for (final assetPath in assetPaths) {
        try {
          final quickJsSource = await loadQuickJsSource(
            assetPath,
            debug: debug,
          );
          if (quickJsSource != null) {
            registry.replace(quickJsSource);
            _registerBuiltInScript(quickJsSource);
            loadedCount += 1;
            debug.add(
              strings.sourceLoaded((assetPath).toString()),
              category: 'App',
            );
          }
        } catch (error) {
          _runtimeError = error.toString();
          debug.add(
            strings.sourceLoadFailed(
              (assetPath).toString(),
              (error).toString(),
            ),
            level: DebugLogLevel.error,
            category: 'App',
          );
        }
      }
      if (loadedCount > 0) {
        _applyStoredSourcePreferences();
        _sourceRuntimeReady = true;
        notifyListeners();
      }
    } finally {
      if (!_ready.isCompleted) _ready.complete();
      unawaited(_resumeRestoredDownloads());
    }
  }

  Future<SourceImportResult> importSourceBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    await ready;
    final entries = sourceScriptsFromBytes(bytes, fileName);
    final imported = <ApkSource>[];
    final failures = <String, String>{};
    final loaded = <({String name, ApkSourceScript script})>[];

    for (final entry in entries) {
      try {
        if (entry.error != null || entry.text == null) {
          throw entry.error ?? FormatException(strings.sourceReadFailed);
        }
        final script = await loadQuickJsSourceText(
          entry.text!,
          sourceUrl: entry.name,
          debug: debug,
        );
        if (script == null) {
          throw UnsupportedError(strings.sourceImportUnsupported);
        }
        if (script.id == 'quickjs-source') {
          throw FormatException(strings.sourceMissingId);
        }
        loaded.add((name: entry.name, script: script));
      } catch (error) {
        failures[entry.name] = error.toString();
      }
    }

    final acceptedIds = <String>{};
    for (final item in loaded) {
      final duplicate =
          !acceptedIds.add(item.script.id) ||
          _sources.any((source) => source.id == item.script.id);
      if (duplicate) {
        failures[item.name] = strings.sourceIdExists(
          (item.script.id).toString(),
        );
        await item.script.dispose();
        continue;
      }
      registry.replace(item.script);
      final source = _sourceForScript(item.script, builtIn: false);
      _sources = [..._sources, source];
      imported.add(source);
    }

    if (imported.isNotEmpty) {
      _refreshSourceView();
      notifyListeners();
      debug.add(
        strings.sourcesImportedWithErrors(
          (imported.length).toString(),
          (failures.length).toString(),
        ),
        category: 'App',
      );
    }
    return SourceImportResult(imported: imported, failures: failures);
  }

  Future<SourceImportResult> importSourceUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException(strings.sourceHttpsRequired);
    }
    final bytes = await host.requestBytes(
      uri.toString(),
      policy: SourcePolicy(allowedHosts: {uri.host}),
    );
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final fileName = lastSegment.contains('.') ? lastSegment : 'source.js';
    return importSourceBytes(Uint8List.fromList(bytes), fileName);
  }

  Future<List<SourceTestResult>> testAllSources({
    String query = 'hello',
    Set<String>? sourceIds,
    void Function(SourceTestResult result)? onResult,
  }) async {
    await ready;
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final sourceSnapshot = _sources
        .where(
          (source) =>
              source.status == SourceStatus.enabled &&
              (sourceIds == null || sourceIds.contains(source.id)),
        )
        .toList(growable: false);
    final availableSourceIds = sourceSnapshot
        .map((source) => source.id)
        .toSet();
    final sourcesById = {
      for (final source in sourceSnapshot) source.id: source,
    };
    final reportedSourceIds = <String>{};
    SourceTestResult resultFor(ApkSource source, SourceSearchPage? page) =>
        SourceTestResult(
          sourceId: source.id,
          sourceName: source.name,
          resultCount: page?.results.length ?? 0,
          error:
              page?.error ??
              (page == null ? strings.sourceRuntimeMissing : null),
        );

    debug.add(
      strings.batchTestStarted((normalized).toString()),
      category: 'Source',
    );
    final pages = await registry.searchPage(
      normalized,
      host,
      enabledSourceIds: availableSourceIds,
      clearErrors: true,
      onSourcePageCompleted: (_, page) {
        final source = sourcesById[page.sourceId];
        if (source == null || !reportedSourceIds.add(source.id)) return;
        onResult?.call(resultFor(source, page));
      },
    );
    final pagesBySource = {for (final page in pages) page.sourceId: page};
    final results = sourceSnapshot
        .map((source) => resultFor(source, pagesBySource[source.id]))
        .toList(growable: false);
    for (final result in results) {
      if (reportedSourceIds.add(result.sourceId)) onResult?.call(result);
    }
    final failed = results.where((result) => !result.succeeded).length;
    debug.add(
      strings.batchTestFinished(
        (results.length - failed).toString(),
        (failed).toString(),
      ),
      category: 'Source',
    );
    return results;
  }

  Future<List<AppListing>> search(
    String query, {
    Set<String>? sourceIds,
    void Function(List<AppListing> results)? onSourceResults,
  }) async {
    await ready;
    debug.add(
      strings.searchStarted((query.trim()).toString()),
      category: 'App',
    );
    final enabledSourceIds = _sources
        .where(
          (source) =>
              source.status == SourceStatus.enabled &&
              (sourceIds == null || sourceIds.contains(source.id)),
        )
        .map((source) => source.id)
        .toSet();
    final results = await registry.search(
      query,
      host,
      enabledSourceIds: enabledSourceIds,
      onSourceCompleted: (_, sourceResults) {
        if (sourceResults.isNotEmpty) onSourceResults?.call(sourceResults);
      },
    );
    for (final entry in sourceErrors.entries) {
      debug.add(
        strings.sourceExecutionFailed(
          (entry.key).toString(),
          (entry.value).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Source',
      );
    }
    debug.add(
      strings.searchFinished((results.length).toString()),
      category: 'App',
    );
    return results;
  }

  Future<List<AppListing>> lookupByPackageName(String packageName) async {
    await ready;
    final normalized = packageName.trim();
    if (normalized.isEmpty) return const [];
    debug.add(
      strings.packageLookupStarted((normalized).toString()),
      category: 'App',
    );
    final enabledSourceIds = _sources
        .where((source) => source.status == SourceStatus.enabled)
        .map((source) => source.id)
        .toSet();
    final results = await registry.lookupByPackageName(
      normalized,
      host,
      enabledSourceIds: enabledSourceIds,
    );
    for (final entry in sourceErrors.entries) {
      debug.add(
        strings.sourceExecutionFailed(
          (entry.key).toString(),
          (entry.value).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Source',
      );
    }
    debug.add(
      strings.packageLookupFinished((results.length).toString()),
      category: 'App',
    );
    return results;
  }

  Future<List<SourceSearchPage>> searchPage(
    String query, {
    int page = 1,
    Set<String>? sourceIds,
    void Function(SourceSearchPage page)? onSourcePage,
    SourceSearchCancellation? cancellation,
  }) async {
    await ready;
    debug.add(
      page == 1
          ? strings.searchStarted((query.trim()).toString())
          : strings.searchPageStarted(
              (page).toString(),
              (query.trim()).toString(),
            ),
      category: 'App',
    );
    final enabledSourceIds = _sources
        .where(
          (source) =>
              source.status == SourceStatus.enabled &&
              (sourceIds == null || sourceIds.contains(source.id)),
        )
        .map((source) => source.id)
        .toSet();
    final pages = await registry.searchPage(
      query,
      host,
      page: page,
      enabledSourceIds: enabledSourceIds,
      clearErrors: page == 1,
      cancellation: cancellation,
      onSourcePageCompleted: (_, result) => onSourcePage?.call(result),
    );
    for (final entry in sourceErrors.entries) {
      debug.add(
        strings.sourceExecutionFailed(
          (entry.key).toString(),
          (entry.value).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Source',
      );
    }
    debug.add(
      strings.searchPageFinished(
        (page).toString(),
        (pages.fold<int>(
          0,
          (total, item) => total + item.results.length,
        )).toString(),
      ),
      category: 'App',
    );
    return pages;
  }

  Future<void> loadDetails(
    AppListing app, {
    required void Function(AppDetailsProgress progress) onProgress,
    bool forceRefresh = false,
  }) async {
    await ready;
    if (!forceRefresh) {
      final cached = cachedDetailsFor(app);
      if (cached != null) {
        onProgress(cached);
        return;
      }
    }

    await registry.loadDetails(
      app,
      host,
      onProgress: (progress) {
        if (progress.phase == DetailLoadPhase.complete && !_isDisposing) {
          _detailsCache.putIfAbsent(app.sourceId, () => {})[app.id] = progress;
        }
        onProgress(progress);
      },
    );
  }

  Future<AppDownloadResult> downloadApp(AppListing app) async {
    final result = await downloadApps([app]);
    return result.results.single;
  }

  Future<AppBatchDownloadResult> downloadApps(Iterable<AppListing> apps) async {
    await _settingsReady;
    final unique = <String, AppListing>{};
    for (final app in apps) {
      final key = _appKey(app);
      if (key != null) unique[key] = app;
    }
    if (unique.isEmpty) return const AppBatchDownloadResult([]);

    final results = await Future.wait(
      unique.values.map(_resolveAndStartAppDownloads),
    );
    return AppBatchDownloadResult(List.unmodifiable(results));
  }

  Future<AppDownloadResult> _resolveAndStartAppDownloads(AppListing app) async {
    AppDetailsProgress? progress;
    try {
      await loadDetails(app, onProgress: (value) => progress = value);
      final loaded = progress;
      if (loaded == null) {
        throw StateError(strings.noAppDetails);
      }

      final filesByUrl = <String, SourceDownload>{};
      final errors = <String>[];
      for (final download in loaded.downloads) {
        if (download.error != null) {
          errors.add('${download.candidate.label}：${download.error}');
        } else if (download.files != null && download.files!.isEmpty) {
          errors.add(
            strings.candidateNoLinks((download.candidate.label).toString()),
          );
        }
        for (final file in download.files ?? const <SourceDownload>[]) {
          if (file.url.trim().isNotEmpty) filesByUrl[file.url] = file;
        }
      }
      if (filesByUrl.isEmpty) {
        final detailFiles = loaded.details.downloads;
        for (final file in detailFiles) {
          if (file.url.trim().isNotEmpty) filesByUrl[file.url] = file;
        }
      }
      if (filesByUrl.isEmpty) {
        throw StateError(
          errors.isEmpty
              ? (loaded.error ?? strings.noDownloadLinks)
              : errors.join('；'),
        );
      }

      var startedFiles = 0;
      for (final file in filesByUrl.values) {
        try {
          await download(file, app.sourceId, app: loaded.details);
          startedFiles += 1;
        } catch (error) {
          errors.add(error.toString());
        }
      }
      return AppDownloadResult(
        app: app,
        startedFiles: startedFiles,
        error: errors.isEmpty ? null : errors.join('；'),
      );
    } catch (error) {
      return AppDownloadResult(
        app: app,
        startedFiles: 0,
        error: error.toString(),
      );
    }
  }

  AppDetailsProgress? cachedDetailsFor(AppListing app) =>
      _detailsCache[app.sourceId]?[app.id];

  void cacheDetails(AppListing app, AppDetails details) {
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
    _detailsCache.putIfAbsent(
      app.sourceId,
      () => {},
    )[app.id] = AppDetailsProgress(
      details: details,
      downloads: List.unmodifiable(downloads),
      phase: DetailLoadPhase.complete,
    );
  }

  Future<AppDetails> details(AppListing app) async {
    await ready;
    return registry.details(app, host);
  }

  Future<SourceCatalog> catalog() async {
    await ready;
    return registry.catalog(
      host,
      enabledSourceIds: homeSourceId == null ? const {} : {homeSourceId!},
    );
  }

  Future<SourceCatalogPage> catalogPage(
    SourceCatalogTab tab, {
    int page = 1,
  }) async {
    await ready;
    if (tab.sourceId != homeSourceId) {
      throw StateError(strings.wrongHomeSource);
    }
    return registry.catalogPage(tab, host, page: page);
  }

  Future<DebugProjectResult> runDebugProject(
    SourceDebugProject project,
    String input,
  ) async {
    final enabled = _sources.any(
      (source) =>
          source.id == project.sourceId &&
          source.status == SourceStatus.enabled,
    );
    if (!enabled) {
      throw StateError(strings.sourceDisabled((project.sourceName).toString()));
    }
    debug.add(
      strings.debugProjectStarted(
        (project.name).toString(),
        (project.sourceName).toString(),
      ),
      category: 'Debug',
    );
    try {
      final result = await registry.runDebugProject(project, input, host);
      debug.add(result.summary, category: 'Debug');
      return result;
    } catch (error) {
      debug.add(
        strings.debugProjectError(
          (project.name).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Debug',
      );
      rethrow;
    }
  }

  void _handleDownloadNotificationAction(String id, String action) {
    final task = _downloadById(id);
    if (task == null) return;
    switch (action) {
      case 'pause':
        unawaited(pauseDownload(task));
      case 'resume':
        unawaited(resumeDownload(task));
      case 'stop':
        unawaited(cancelDownload(task));
      case 'install':
        unawaited(_installFromNotification(task));
    }
  }

  Future<void> _installFromNotification(DownloadTask task) async {
    try {
      await installTask(task);
    } catch (error) {
      debug.add(
        strings.notificationInstallFailed(
          (task.file.label).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Download',
      );
    }
  }

  DownloadTask? downloadFor(String url) {
    for (final task in _downloads) {
      if (task.file.url == url) return task;
    }
    return null;
  }

  DownloadPolicySnapshot _policySnapshot(SourcePolicy policy) =>
      DownloadPolicySnapshot(
        allowedHosts: List<String>.unmodifiable(policy.allowedHosts),
        allowInstall: policy.allowInstall,
      );

  SourcePolicy _policyForTask(DownloadTask task) {
    try {
      return registry.scriptFor(task.sourceId).policy;
    } catch (_) {
      final snapshot = task.policy;
      if (snapshot == null) {
        throw StateError(strings.downloadSourceMissing);
      }
      return SourcePolicy(
        allowedHosts: snapshot.allowedHosts.toSet(),
        allowDownload: true,
        allowInstall: snapshot.allowInstall,
      );
    }
  }

  Future<DownloadMethod> download(
    SourceDownload file,
    String sourceId, {
    AppListing? app,
  }) async {
    await _settingsReady;
    if (_isDisposing) throw StateError(strings.appStateClosed);
    final method = _downloadMethod;
    final policy = registry.scriptFor(sourceId).policy;
    if (!policy.allowDownload) {
      throw StateError(strings.downloadPermissionMissing);
    }
    if (method == DownloadMethod.internal) {
      startDownload(file, sourceId, app: app);
      return method;
    }

    final uri = Uri.tryParse(file.url);
    if (uri == null || !policy.permits(uri)) {
      throw StateError(strings.downloadUrlDenied);
    }

    final launched = switch (method) {
      DownloadMethod.browser => await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ),
      DownloadMethod.externalDownloader =>
        await external_download.launchExternalDownloader(
          uri,
          fileName: file.label,
          headers: file.headers,
        ),
      DownloadMethod.internal => true,
    };
    if (!launched) {
      throw StateError(
        method == DownloadMethod.browser
            ? strings.noBrowser
            : strings.noExternalDownloader,
      );
    }
    debug.add(
      strings.externalDownloadReceived(
        (method == DownloadMethod.browser
                ? strings.browser
                : strings.externalDownloader)
            .toString(),
        (file.label).toString(),
      ),
      category: 'Download',
    );
    return method;
  }

  DownloadTask startDownload(
    SourceDownload file,
    String sourceId, {
    AppListing? app,
  }) {
    final existing = downloadFor(file.url);
    if (existing != null && existing.status == DownloadStatus.downloading) {
      return existing;
    }
    if (existing != null && existing.status == DownloadStatus.paused) {
      unawaited(resumeDownload(existing));
      return existing;
    }
    if (existing != null && existing.status == DownloadStatus.completed) {
      return existing;
    }

    final now = DateTime.now();
    final policySnapshot = _policySnapshot(
      existing == null
          ? registry.scriptFor(sourceId).policy
          : _policyForTask(existing),
    );
    late final DownloadTask task;
    if (existing == null) {
      task = DownloadTask(
        id: '${now.microsecondsSinceEpoch}-${_downloadSequence++}',
        file: file,
        sourceId: sourceId,
        status: DownloadStatus.downloading,
        startedAt: now,
        policy: policySnapshot,
        app: app,
      );
      _downloads.insert(0, task);
    } else {
      task = existing.copyWith(
        status: DownloadStatus.downloading,
        startedAt: now,
        received: 0,
        total: null,
        speedBytesPerSecond: null,
        policy: policySnapshot,
        filePath: null,
        error: null,
        completedAt: null,
        app: app ?? existing.app,
      );
      _replaceDownload(task, notify: false);
    }

    _downloadProgressSamples.remove(task.id);
    _installInfos.remove(task.id);
    _installStateChecks.remove(task.id);
    _scheduleDownloadPersistence();
    debug.add(
      strings.downloadStarting((file.label).toString()),
      category: 'Download',
    );
    notifyListeners();
    unawaited(_runDownload(task.id));
    return task;
  }

  DownloadTask retryDownload(DownloadTask task) {
    if (task.status == DownloadStatus.paused) {
      unawaited(resumeDownload(task));
      return task;
    }
    return startDownload(task.file, task.sourceId);
  }

  Future<void> pauseDownload(DownloadTask task) async {
    final current = _downloadById(task.id);
    if (current?.status != DownloadStatus.downloading) return;
    _downloadProgressSamples.remove(current!.id);
    _replaceDownload(
      current.copyWith(
        status: DownloadStatus.paused,
        speedBytesPerSecond: null,
      ),
    );
    debug.add(
      strings.downloadPausing((current.file.label).toString()),
      category: 'Download',
    );
    try {
      await host.pauseDownload(current.id);
      final paused = _downloadById(current.id);
      if (paused?.status == DownloadStatus.paused) {
        await _downloadNotifications.showPaused(
          id: paused!.id,
          title: paused.file.label,
          received: paused.received,
          total: paused.total,
        );
      }
    } catch (error) {
      _replaceDownload(
        current.copyWith(
          status: DownloadStatus.downloading,
          speedBytesPerSecond: null,
        ),
      );
      final restored = _downloadById(current.id);
      if (restored != null) {
        unawaited(
          _downloadNotifications.showProgress(
            id: restored.id,
            title: restored.file.label,
            received: restored.received,
            total: restored.total,
          ),
        );
      }
      debug.add(
        strings.downloadPauseFailed(
          (current.file.label).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Download',
      );
    }
  }

  Future<void> resumeDownload(DownloadTask task) async {
    final current = _downloadById(task.id);
    if (current?.status != DownloadStatus.paused) return;
    _downloadProgressSamples.remove(current!.id);
    _replaceDownload(
      current.copyWith(
        status: DownloadStatus.downloading,
        speedBytesPerSecond: null,
      ),
    );
    debug.add(
      strings.downloadResuming((current.file.label).toString()),
      category: 'Download',
    );
    if (!host.hasDownloadSession(current.id)) {
      unawaited(_runDownload(current.id));
      return;
    }
    try {
      await host.resumeDownload(current.id);
      final resumed = _downloadById(current.id);
      if (resumed?.status == DownloadStatus.downloading) {
        unawaited(
          _downloadNotifications.showProgress(
            id: resumed!.id,
            title: resumed.file.label,
            received: resumed.received,
            total: resumed.total,
          ),
        );
      }
    } catch (error) {
      _replaceDownload(current.copyWith(status: DownloadStatus.paused));
      final paused = _downloadById(current.id);
      if (paused != null) {
        unawaited(
          _downloadNotifications.showPaused(
            id: paused.id,
            title: paused.file.label,
            received: paused.received,
            total: paused.total,
          ),
        );
      }
      debug.add(
        strings.downloadResumeFailed(
          (current.file.label).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.error,
        category: 'Download',
      );
    }
  }

  Future<void> cancelDownload(DownloadTask task) async {
    final current = _downloadById(task.id);
    if (current == null) return;
    if (current.status != DownloadStatus.downloading &&
        current.status != DownloadStatus.paused) {
      return;
    }
    _removeDownload(current.id);
    debug.add(
      strings.downloadCanceling((current.file.label).toString()),
      category: 'Download',
    );
    await _downloadNotifications.cancel(current.id);
    try {
      await host.cancelDownload(current.id);
    } catch (error) {
      debug.add(
        strings.downloadCancelCleanupFailed(
          (current.file.label).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.warning,
        category: 'Download',
      );
    }
  }

  Future<void> deleteDownload(DownloadTask task) async {
    final current = _downloadById(task.id);
    if (current == null ||
        (current.status != DownloadStatus.completed &&
            current.status != DownloadStatus.failed) ||
        _installingDownloads.contains(current.id)) {
      return;
    }

    await _downloadNotifications.cancel(current.id);
    try {
      await host.removeDownloadFiles(current.id, filePath: current.filePath);
    } catch (error) {
      debug.add(
        strings.downloadDeleteFailed(
          (current.file.label).toString(),
          (error).toString(),
        ),
        level: DebugLogLevel.warning,
        category: 'Download',
      );
    }
    _removeDownload(current.id);
    debug.add(
      strings.downloadDeleting((current.file.label).toString()),
      category: 'Download',
    );
  }

  Future<void> clearDownloads({required bool completedOnly}) async {
    final targets = _downloads
        .where(
          (task) => !completedOnly || task.status == DownloadStatus.completed,
        )
        .toList(growable: false);
    if (targets.isEmpty) return;

    for (final task in targets) {
      if (task.status != DownloadStatus.downloading &&
          task.status != DownloadStatus.paused) {
        continue;
      }
      await _downloadNotifications.cancel(task.id);
      try {
        await host.cancelDownload(task.id);
      } catch (error) {
        debug.add(
          strings.downloadSessionCleanupFailed(
            (task.file.label).toString(),
            (error).toString(),
          ),
          level: DebugLogLevel.warning,
          category: 'Download',
        );
      }
    }

    for (final task in targets) {
      try {
        await host.removeDownloadFiles(task.id, filePath: task.filePath);
      } catch (error) {
        debug.add(
          strings.downloadDeleteFailed(
            (task.file.label).toString(),
            (error).toString(),
          ),
          level: DebugLogLevel.warning,
          category: 'Download',
        );
      }
      _removeDownload(task.id, notify: false);
    }
    notifyListeners();
    _scheduleDownloadPersistence(immediate: true);
  }

  Future<void> _runDownload(String taskId) async {
    if (_isDisposing) return;
    final task = _downloadById(taskId);
    if (task == null) return;
    await _downloadNotifications.requestPermission();
    final beforeNotification = _downloadById(task.id);
    if (beforeNotification == null ||
        beforeNotification.status != DownloadStatus.downloading) {
      await _downloadNotifications.cancel(task.id);
      return;
    }
    await _downloadNotifications.showProgress(
      id: task.id,
      title: task.file.label,
      received: beforeNotification.received,
      total: beforeNotification.total,
    );
    final beforeStart = _downloadById(task.id);
    if (beforeStart == null ||
        beforeStart.status != DownloadStatus.downloading) {
      await _downloadNotifications.cancel(task.id);
      return;
    }

    try {
      final path = await host.download(
        task.file.url,
        headers: task.file.headers,
        downloadId: task.id,
        fileName:
            RegExp(
              r'\.(apk|apks|xapk|zip)$',
              caseSensitive: false,
            ).hasMatch(task.file.label)
            ? task.file.label
            : null,
        policy: _policyForTask(task),
        onProgress: (received, total) =>
            _queueDownloadProgress(task.id, received, total),
      );
      _flushDownloadProgress(task.id);
      final current = _downloadById(task.id);
      if (current == null) return;
      if (current.status == DownloadStatus.canceled) {
        await _downloadNotifications.cancel(task.id);
        return;
      }
      _downloadProgressSamples.remove(task.id);
      final completed = current.copyWith(
        status: DownloadStatus.completed,
        filePath: path,
        speedBytesPerSecond: null,
        error: null,
        completedAt: DateTime.now(),
      );
      _replaceDownload(completed);
      debug.add(
        strings.downloadCompleted((task.file.label).toString()),
        category: 'Download',
      );
      await _downloadNotifications.showCompleted(
        id: task.id,
        title: task.file.label,
      );
    } catch (error) {
      if (_isDisposing) return;
      _flushDownloadProgress(task.id);
      final current = _downloadById(task.id);
      if (current == null) return;
      if (error is DownloadCancelledException) {
        _removeDownload(current.id);
        debug.add(
          strings.downloadCanceled((task.file.label).toString()),
          category: 'Download',
        );
        await _downloadNotifications.cancel(task.id);
        return;
      }
      _downloadProgressSamples.remove(task.id);
      _replaceDownload(
        current.copyWith(
          status: DownloadStatus.failed,
          speedBytesPerSecond: null,
          error: error.toString(),
          completedAt: DateTime.now(),
        ),
      );
      debug.add(
        strings.downloadError((task.file.label).toString(), (error).toString()),
        level: DebugLogLevel.error,
        category: 'Download',
      );
      await _downloadNotifications.showFailed(
        id: task.id,
        title: task.file.label,
        error: error.toString(),
      );
    }
  }

  void _queueDownloadProgress(String id, int received, int? total) {
    _pendingDownloadBytes[id] = received;
    _pendingDownloadTotals[id] = total;
    _downloadProgressTimers.putIfAbsent(
      id,
      () => Timer(
        const Duration(milliseconds: 250),
        () => _flushDownloadProgress(id),
      ),
    );
  }

  void _flushDownloadProgress(String id) {
    _downloadProgressTimers.remove(id)?.cancel();
    final received = _pendingDownloadBytes.remove(id);
    final total = _pendingDownloadTotals.remove(id);
    final task = _downloadById(id);
    if (received == null ||
        task == null ||
        task.status != DownloadStatus.downloading) {
      return;
    }

    final now = DateTime.now();
    final previous = _downloadProgressSamples[id];
    final elapsed = previous == null
        ? null
        : now.difference(previous.timestamp).inMilliseconds;
    final delta = previous == null ? null : received - previous.received;
    _downloadProgressSamples[id] = (received: received, timestamp: now);

    final measuredSpeed =
        elapsed != null && elapsed > 0 && delta != null && delta >= 0
        ? (delta * 1000 / elapsed).round()
        : null;
    final speed = measuredSpeed == null
        ? task.speedBytesPerSecond
        : task.speedBytesPerSecond == null
        ? measuredSpeed
        : (task.speedBytesPerSecond! * .7 + measuredSpeed * .3).round();
    final updated = task.copyWith(
      received: received,
      total: total,
      speedBytesPerSecond: speed,
    );
    _replaceDownload(updated);
    unawaited(
      _downloadNotifications.showProgress(
        id: id,
        title: updated.file.label,
        received: received,
        total: total,
      ),
    );
  }

  DownloadTask? _downloadById(String id) {
    for (final task in _downloads) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _replaceDownload(DownloadTask task, {bool notify = true}) {
    final index = _downloads.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    _downloads[index] = task;
    _scheduleDownloadPersistence();
    if (notify) notifyListeners();
  }

  void _removeDownload(String id, {bool notify = true}) {
    final index = _downloads.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _downloadProgressTimers.remove(id)?.cancel();
    _pendingDownloadBytes.remove(id);
    _pendingDownloadTotals.remove(id);
    _downloadProgressSamples.remove(id);
    _installInfos.remove(id);
    _installStateChecks.remove(id);
    _installingDownloads.remove(id);
    _downloads.removeAt(index);
    _scheduleDownloadPersistence();
    if (notify) notifyListeners();
  }

  Future<bool> installTask(DownloadTask task) async {
    await _settingsReady;
    final current = _downloadById(task.id) ?? task;
    final path = current.filePath;
    if (path == null) throw StateError(strings.downloadNotComplete);
    if (!_installingDownloads.add(current.id)) {
      throw StateError(strings.installationInProgress);
    }
    notifyListeners();
    try {
      final installed = await host.install(
        path,
        policy: _policyForTask(current),
        userInitiated: true,
      );
      if (installed) await refreshInstallState(current);
      return installed;
    } finally {
      _installingDownloads.remove(current.id);
      if (!_isDisposing) notifyListeners();
    }
  }

  Future<bool> install(String path, String sourceId) async {
    await _settingsReady;
    final script = registry.scriptFor(sourceId);
    return host.install(path, policy: script.policy, userInitiated: true);
  }

  void setHomeSource(String id) {
    ApkSource? selected;
    for (final source in _sources) {
      if (source.id == id && source.status == SourceStatus.enabled) {
        selected = source;
        break;
      }
    }
    if (selected == null) return;
    _sources = _sources
        .map((item) => item.copyWith(homeSource: item.id == selected!.id))
        .toList();
    _preferredHomeSourceId = selected.id;
    _refreshSourceView();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void toggleSource(String id, bool enabled) {
    _sources = _sources
        .map(
          (source) => source.id == id
              ? source.copyWith(
                  status: enabled
                      ? SourceStatus.enabled
                      : SourceStatus.disabled,
                  homeSource: enabled ? source.homeSource : false,
                )
              : source,
        )
        .toList();
    _disabledSourceIds = _sources
        .where((source) => source.status == SourceStatus.disabled)
        .map((source) => source.id)
        .toSet();
    if (!enabled && _preferredHomeSourceId == id) {
      _preferredHomeSourceId = null;
    }
    _refreshSourceView();
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setSourcesEnabled(Iterable<String> ids, bool enabled) {
    final sourceIds = ids.toSet();
    if (sourceIds.isEmpty) return;
    var changed = false;
    _sources = _sources.map((source) {
      if (!sourceIds.contains(source.id)) return source;
      final nextStatus = enabled ? SourceStatus.enabled : SourceStatus.disabled;
      if (source.status == nextStatus && (enabled || !source.homeSource)) {
        return source;
      }
      changed = true;
      return source.copyWith(
        status: nextStatus,
        homeSource: enabled ? source.homeSource : false,
      );
    }).toList();
    if (changed) {
      _disabledSourceIds = _sources
          .where((source) => source.status == SourceStatus.disabled)
          .map((source) => source.id)
          .toSet();
      final currentHome = _sources
          .where((source) => source.homeSource)
          .map((source) => source.id)
          .firstOrNull;
      _preferredHomeSourceId = currentHome;
      _refreshSourceView();
      notifyListeners();
      unawaited(_persistSettings());
    }
  }

  void enableSources(Iterable<String> ids) => setSourcesEnabled(ids, true);

  void disableSources(Iterable<String> ids) => setSourcesEnabled(ids, false);

  void removeSource(String id) {
    final source = _sources.where((item) => item.id == id).firstOrNull;
    if (source == null || source.builtIn) return;
    _sources.removeWhere((item) => item.id == id);
    _disabledSourceIds.remove(id);
    if (_preferredHomeSourceId == id) _preferredHomeSourceId = null;
    _refreshSourceView();
    unawaited(registry.remove(id));
    notifyListeners();
    unawaited(_persistSettings());
  }

  void addSource(ApkSource source) {
    _sources = [..._sources, source];
    _refreshSourceView();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _downloadPersistenceTimer?.cancel();
    _downloadPersistenceTimer = null;
    if (_downloads.isNotEmpty) _persistDownloadsNow();
    for (final timer in _downloadProgressTimers.values) {
      timer.cancel();
    }
    _downloadProgressTimers.clear();
    _downloadProgressSamples.clear();
    for (final task in _downloads) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.paused) {
        unawaited(_downloadNotifications.cancel(task.id));
      }
    }
    _translationQueueTimer?.cancel();
    _translationQueueTimer = null;
    _detailsCache.clear();
    translation.dispose();
    unawaited(host.dispose());
    registry.dispose();
    debug.dispose();
    super.dispose();
  }
}
