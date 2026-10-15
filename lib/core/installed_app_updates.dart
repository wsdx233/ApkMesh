import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'installed_update_store.dart';
import 'models.dart';
import 'source_runtime.dart';

/// Host-only installed inventory; scripts receive only the package being looked up.
class InstalledAppUpdateService extends ChangeNotifier {
  InstalledAppUpdateService({
    required this.host,
    required this.registry,
    required this.store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const cacheTtl = Duration(hours: 24);
  static const retryDelay = Duration(hours: 1);
  static const concurrency = 2;

  final SourceHostApi host;
  final SourceRegistry registry;
  final InstalledUpdateStore store;
  final DateTime Function() _now;
  final Map<String, InstalledAppUpdateRecord> _records = {};
  final Map<String, _UpdateTarget> _targets = {};
  final Set<String> _pending = {};
  final Set<String> _running = {};
  final Set<String> _queued = {};
  final Queue<String> _queue = Queue();
  List<DownloadTask> _downloads = const [];
  Set<String> _sourceIds = const {};
  Future<void>? _load;
  Future<void>? _refresh;
  Future<void> _writes = Future.value();
  Completer<void>? _idle;
  Timer? _timer;
  bool _automatic = true;
  bool _foreground = true;
  bool _manual = false;
  bool _requested = false;
  bool _force = false;
  bool _disposed = false;
  DateTime? _scanRetryAt;

  DateTime? lastCheckedAt;
  String? lastError;

  bool get isChecking =>
      _refresh != null ||
      _running.isNotEmpty ||
      (_foreground && (_automatic || _manual) && _queue.isNotEmpty);
  int get pendingCount => _pending.length;
  int get failedCount => _records.values
      .where(
        (record) =>
            _sourceIds.contains(record.sourceId) &&
            _targets.containsKey(record.key) &&
            record.status == InstalledAppUpdateStatus.failed,
      )
      .length;
  List<InstalledAppUpdateRecord> get updates => List.unmodifiable(
    _records.values.where(
      (record) =>
          _sourceIds.contains(record.sourceId) &&
          _targets.containsKey(record.key) &&
          record.isAvailable,
    ),
  );

  void configure({
    required List<DownloadTask> downloads,
    required Set<String> enabledSourceIds,
    required bool automatic,
  }) {
    _downloads = downloads;
    _sourceIds = enabledSourceIds;
    _automatic = automatic;
    _targets.removeWhere((_, target) => !_sourceIds.contains(target.sourceId));
    if (!_automatic) _timer?.cancel();
    _queue.removeWhere((key) => !_targets.containsKey(key));
    _queued.removeWhere((key) => !_targets.containsKey(key));
    _drain();
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) _timer?.cancel();
    _drain();
  }

  Future<void> refresh({bool force = false, bool manual = false}) async {
    if (_disposed || (!_automatic && !manual)) return;
    _manual |= manual;
    _requested = true;
    _force |= force;
    _idle ??= Completer<void>();
    _refresh ??= _prepare().whenComplete(() {
      _refresh = null;
      if (!_disposed) {
        _drain();
        notifyListeners();
      }
    });
    notifyListeners();
    await _refresh;
    if (!_disposed &&
        (_running.isNotEmpty ||
            (_foreground &&
                (_automatic || _manual) &&
                _queue.isNotEmpty &&
                _scanRetryAt == null))) {
      await (_idle ??= Completer<void>()).future;
    }
  }

  Future<void> _restore() async {
    try {
      final saved = await store.load();
      if (_disposed) return;
      for (final record in saved.records) {
        _records[record.key] = record;
      }
      _pending.addAll(saved.pendingKeys);
    } catch (_) {
      _load = null;
      rethrow;
    }
  }

  Future<void> _prepare() async {
    try {
      await (_load ??= _restore());
      while (_requested && !_disposed) {
        _requested = false;
        final force = _force;
        _force = false;
        final inventory = {
          for (final app in await host.installedApps()) app.packageName: app,
        };
        if (_disposed) return;
        final targets = <String, _UpdateTarget>{};
        for (final script in registry.scripts) {
          if (!_sourceIds.contains(script.id) ||
              script is! SourcePackageLookupScript ||
              !(script as SourcePackageLookupScript).supportsPackageLookup) {
            continue;
          }
          for (final installed in inventory.values) {
            final key = _packageKey(script.id, installed.packageName);
            targets[key] = _UpdateTarget(
              sourceId: script.id,
              installed: installed,
              appId: _records[key]?.latest == null
                  ? null
                  : _records[key]!.appId,
            );
          }
        }
        final previousPackages = {
          for (final record in _records.values)
            if (record.packageName.isNotEmpty)
              '${record.sourceId}\u0000${record.appId}': record.packageName,
        };
        for (final task in _downloads) {
          final app = task.app;
          if (task.status != DownloadStatus.completed ||
              app == null ||
              !_sourceIds.contains(app.sourceId)) {
            continue;
          }
          var packageName = app.packageName.trim().isNotEmpty
              ? app.packageName.trim()
              : previousPackages['${app.sourceId}\u0000${app.id}'] ?? '';
          String? archiveError;
          if (packageName.isEmpty && task.filePath != null) {
            try {
              final archive = await host.inspectInstall(task.filePath!);
              packageName = archive.packageName?.trim() ?? '';
              archiveError = archive.error;
            } catch (error) {
              archiveError = error.toString();
            }
            if (_disposed) return;
          }
          final key = packageName.isEmpty
              ? '${app.sourceId}\u0000app:${app.id}'
              : _packageKey(app.sourceId, packageName);
          targets.putIfAbsent(key, () => _UpdateTarget(sourceId: app.sourceId));
          // Downloads are newest-first; keep the first source app ID for a package.
          if (targets[key]!.download == null) {
            targets[key] = _UpdateTarget(
              sourceId: app.sourceId,
              installed: inventory[packageName],
              appId: app.id,
              download: task,
              packageName: packageName,
              archiveError: archiveError,
            );
          }
        }
        _targets
          ..clear()
          ..addAll(targets);
        _records.removeWhere(
          (key, record) =>
              !targets.containsKey(key) &&
              (_sourceIds.contains(record.sourceId) ||
                  !registry.scripts.any(
                    (script) => script.id == record.sourceId,
                  )),
        );
        _pending.removeWhere(
          (key) => !targets.containsKey(key) && !_records.containsKey(key),
        );
        _queue.removeWhere((key) => !targets.containsKey(key));
        _queued.removeWhere((key) => !targets.containsKey(key));
        final now = _now();
        for (final entry in targets.entries) {
          var record = _records[entry.key];
          final installed = entry.value.installed;
          if (installed == null && record?.installed != null) {
            record = InstalledAppUpdateRecord(
              key: entry.key,
              sourceId: entry.value.sourceId,
              appId: entry.value.appId!,
              packageName: entry.value.packageName,
              status: InstalledAppUpdateStatus.notInstalled,
              checkedAt: now,
            );
            _records[entry.key] = record;
          } else if (installed != null &&
              record?.status == InstalledAppUpdateStatus.notInstalled) {
            record = null;
          }
          if (record?.status != InstalledAppUpdateStatus.failed &&
              record?.latest != null &&
              installed != null &&
              (record!.installed?.versionName != installed.versionName ||
                  record.installed?.versionCode != installed.versionCode)) {
            try {
              record = _success(
                entry.key,
                entry.value,
                installed,
                record.latest,
                record.checkedAt,
              );
              _records[entry.key] = record;
            } on FormatException {
              record = null;
            }
          }
          final due =
              force ||
              record == null ||
              (record.status == InstalledAppUpdateStatus.failed
                  ? record.nextRetryAt == null ||
                        !now.isBefore(record.nextRetryAt!)
                  : now.difference(record.checkedAt) >= cacheTtl);
          if (_pending.contains(entry.key) || due) _enqueue(entry.key);
        }
        lastCheckedAt = now;
        _scanRetryAt = null;
        lastError = null;
        // A killed process must recover queued AND running requests before any I/O starts.
        await _persist();
      }
    } catch (error) {
      if (_disposed) return;
      lastError = error.toString();
      _scanRetryAt = _now().add(retryDelay);
    }
  }

  static String _packageKey(String sourceId, String packageName) =>
      '$sourceId\u0000package:$packageName';

  void _enqueue(String key) {
    _pending.add(key);
    if (!_running.contains(key) && _queued.add(key)) _queue.add(key);
  }

  void _drain() {
    if (_disposed || _refresh != null) return;
    if (_foreground && (_automatic || _manual) && _scanRetryAt == null) {
      while (_running.length < concurrency && _queue.isNotEmpty) {
        final key = _queue.removeFirst();
        _queued.remove(key);
        final target = _targets[key];
        if (target == null ||
            !_sourceIds.contains(target.sourceId) ||
            !_pending.contains(key)) {
          continue;
        }
        _running.add(key);
        unawaited(_run(key, target));
      }
    }
    if (_running.isEmpty &&
        (_queue.isEmpty ||
            !_foreground ||
            (!_automatic && !_manual) ||
            _scanRetryAt != null)) {
      _manual = false;
      _idle?.complete();
      _idle = null;
      _schedule();
    }
  }

  Future<void> _run(String key, _UpdateTarget target) async {
    InstalledAppUpdateRecord record;
    try {
      final installed = target.installed;
      final packageName = installed?.packageName ?? target.packageName;
      if (target.archiveError != null) throw StateError(target.archiveError!);
      if (installed == null) {
        record = InstalledAppUpdateRecord(
          key: key,
          sourceId: target.sourceId,
          appId: target.appId!,
          packageName: packageName,
          status: InstalledAppUpdateStatus.notInstalled,
          checkedAt: _now(),
        );
      } else {
        final latest = await _latest(target, installed.packageName);
        record = _success(key, target, installed, latest, _now());
      }
    } catch (error) {
      final previous = _records[key];
      record = InstalledAppUpdateRecord(
        key: key,
        sourceId: target.sourceId,
        appId: target.appId ?? target.installed!.packageName,
        packageName: target.installed?.packageName ?? target.packageName,
        status: InstalledAppUpdateStatus.failed,
        installed: target.installed ?? previous?.installed,
        latest: previous?.latest,
        checkedAt: _now(),
        error: error.toString(),
        nextRetryAt: _now().add(retryDelay),
      );
    }
    try {
      if (_disposed) return;
      final current = _targets[key];
      if (current == null || !_sourceIds.contains(target.sourceId)) return;
      if (!target.sameRequest(current)) {
        _running.remove(key);
        _enqueue(key);
        return;
      }
      _records[key] = record;
      _pending.remove(key);
      await _persist();
    } catch (error) {
      if (!_disposed) lastError = error.toString();
    } finally {
      _running.remove(key);
      if (!_disposed) {
        _drain();
        notifyListeners();
      }
    }
  }

  Future<AppDetails?> _latest(_UpdateTarget target, String packageName) async {
    final script = registry.scriptFor(target.sourceId);
    var appId = target.appId;
    if (appId == null &&
        script is SourcePackageLookupScript &&
        (script as SourcePackageLookupScript).supportsPackageLookup) {
      appId = await (script as SourcePackageLookupScript).packageLookupUrl(
        packageName,
        host,
      );
    }
    if (appId == null || appId.trim().isEmpty) return null;
    // Never resolve/download APKs merely to compare versions.
    final details =
        script is SourceDetailProgressScript &&
            (script as SourceDetailProgressScript).supportsDetailProgress
        ? (await (script as SourceDetailProgressScript).detailsMetadata(
            appId,
            host,
          )).details
        : await script.details(appId, host);
    if (details.packageName.trim().isNotEmpty &&
        details.packageName.trim() != packageName) {
      throw StateError(
        '更新详情包名与已安装应用不一致：${details.packageName} != $packageName',
      );
    }
    return details;
  }

  InstalledAppUpdateRecord _success(
    String key,
    _UpdateTarget target,
    InstalledAppInfo installed,
    AppListing? latest,
    DateTime checkedAt,
  ) {
    final available =
        latest != null &&
        _compareVersions(latest.version, installed.versionName ?? '') > 0;
    return InstalledAppUpdateRecord(
      key: key,
      sourceId: target.sourceId,
      appId: target.appId ?? latest?.id ?? installed.packageName,
      packageName: installed.packageName,
      installed: installed,
      latest: latest,
      status: latest == null
          ? InstalledAppUpdateStatus.notFound
          : available
          ? InstalledAppUpdateStatus.available
          : InstalledAppUpdateStatus.upToDate,
      checkedAt: checkedAt,
    );
  }

  static int _compareVersions(String latest, String installed) {
    List<int> numbers(String value) {
      final match = RegExp(r'^\s*[vV]?(\d+(?:\.\d+)*)(.*)$').firstMatch(value);
      if (match == null) throw FormatException('无法比较应用版本：$value');
      return match[1]!.split('.').map(int.parse).toList();
    }

    final left = numbers(latest);
    final right = numbers(installed);
    for (var index = 0; index < left.length || index < right.length; index++) {
      final comparison = (index < left.length ? left[index] : 0).compareTo(
        index < right.length ? right[index] : 0,
      );
      if (comparison != 0) return comparison;
    }
    // Equal numeric versions with different vendor/prerelease labels are ambiguous,
    // not an instruction to replace an installed build.
    return 0;
  }

  Future<void> _persist() {
    final snapshot = InstalledUpdateStoreState(
      records: List.unmodifiable(_records.values),
      pendingKeys: Set.unmodifiable(_pending),
    );
    final write = _writes.then((_) => store.save(snapshot));
    _writes = write.catchError((Object _) {});
    return write;
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed || !_foreground || !_automatic) return;
    final now = _now();
    DateTime? next = _scanRetryAt;
    if (_scanRetryAt == null) {
      for (final record in _records.values) {
        if (!_targets.containsKey(record.key)) continue;
        final due = record.status == InstalledAppUpdateStatus.failed
            ? record.nextRetryAt ?? now.add(retryDelay)
            : record.checkedAt.add(cacheTtl);
        if (next == null || due.isBefore(next)) next = due;
      }
    }
    next ??= now.add(cacheTtl);
    final delay = next.difference(now);
    _timer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () => unawaited(refresh()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _idle?.complete();
    _idle = null;
    super.dispose();
  }
}

class _UpdateTarget {
  const _UpdateTarget({
    required this.sourceId,
    this.installed,
    this.appId,
    this.download,
    this.packageName = '',
    this.archiveError,
  });

  final String sourceId;
  final InstalledAppInfo? installed;
  final String? appId;
  final DownloadTask? download;
  final String packageName;
  final String? archiveError;

  bool sameRequest(_UpdateTarget other) =>
      sourceId == other.sourceId &&
      appId == other.appId &&
      installed?.packageName == other.installed?.packageName &&
      installed?.versionName == other.installed?.versionName &&
      installed?.versionCode == other.installed?.versionCode &&
      packageName == other.packageName &&
      archiveError == other.archiveError &&
      download?.filePath == other.download?.filePath;
}
