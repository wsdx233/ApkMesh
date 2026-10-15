import 'dart:async';

import 'package:apk_mesh/core/installed_app_updates.dart';
import 'package:apk_mesh/core/installed_update_store.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'checks installed packages without download records and negative-caches misses',
    () async {
      final host = _Host([
        _installed('com.example.found'),
        _installed('com.example.absent'),
      ]);
      final source = _Source()..missing.add('com.example.absent');
      final store = _Store();
      final service = _service(host, source, store);
      addTearDown(service.dispose);

      await service.refresh();
      expect(service.updates.map((record) => record.packageName), [
        'com.example.found',
      ]);
      expect(
        store.state.records
            .singleWhere((record) => record.packageName == 'com.example.absent')
            .status,
        InstalledAppUpdateStatus.notFound,
      );
      await service.refresh();
      expect(source.lookups, ['com.example.found', 'com.example.absent']);
      expect(source.metadataReads, [
        'https://source.test/apps/com.example.found',
      ]);
    },
  );

  test(
    'download history supports missing package names and survives removal of the APK',
    () async {
      final host = _Host([_installed('com.example.found')])
        ..archive = const ApkInstallInfo(
          supported: true,
          installed: true,
          versionMatches: true,
          canOpen: true,
          packageName: 'com.example.found',
          installedVersionName: '1.0',
          installedVersionCode: 1,
        );
      final source = _Source(lookup: false, packageInDetails: '');
      final store = _Store();
      final service = _service(host, source, store, downloads: [_download]);
      await service.refresh();
      expect(service.updates.single.packageName, 'com.example.found');
      expect(service.updates.single.latest!.id, _download.app!.id);
      service.dispose();

      host.archive = null;
      final restartedSource = _Source(lookup: false, packageInDetails: '');
      final restarted = _service(
        host,
        restartedSource,
        store,
        downloads: [_download],
      );
      addTearDown(restarted.dispose);
      await restarted.refresh();
      expect(restarted.updates.single.latest!.id, _download.app!.id);
      expect(restartedSource.metadataReads, isEmpty);
      expect(host.archiveReads, 1);
    },
  );

  test(
    'fresh cache survives restart and installation changes immediately hide the old update',
    () async {
      final host = _Host([_installed('com.example.found')]);
      final store = _Store();
      final original = _service(host, _Source(), store);
      await original.refresh();
      expect(original.updates.single.latest!.version, '2.0.0.1');
      original.dispose();

      host.inventory = [
        _installed('com.example.found', version: '2.0.0.1', code: 2),
      ];
      final source = _Source();
      final restarted = _service(host, source, store);
      addTearDown(restarted.dispose);
      await restarted.refresh();
      expect(restarted.updates, isEmpty);
      expect(source.lookups, isEmpty);
      expect(source.metadataReads, isEmpty);
      expect(store.state.records.single.installed!.versionCode, 2);
    },
  );

  test(
    'failed queries do not block other apps and retry at the persisted deadline',
    () async {
      var now = DateTime(2026, 10, 14);
      var fail = true;
      final host = _Host([
        _installed('com.example.bad'),
        _installed('com.example.good'),
      ]);
      final source = _Source()
        ..onMetadata = (id) async {
          if (id.endsWith('.bad') && fail) throw StateError('offline');
          return _details(id);
        };
      final store = _Store();
      final service = _service(host, source, store, now: () => now);
      addTearDown(service.dispose);
      await service.refresh();
      expect(service.updates.map((record) => record.packageName), [
        'com.example.good',
      ]);
      expect(service.failedCount, 1);
      final failure = store.state.records.singleWhere(
        (record) => record.packageName == 'com.example.bad',
      );
      expect(failure.nextRetryAt, now.add(const Duration(hours: 1)));

      fail = false;
      now = now.add(const Duration(minutes: 59));
      await service.refresh();
      expect(source.metadataReads.where((id) => id.endsWith('.bad')).length, 1);
      now = now.add(const Duration(minutes: 1));
      await service.refresh();
      expect(service.updates.map((record) => record.packageName).toSet(), {
        'com.example.good',
        'com.example.bad',
      });
      expect(service.failedCount, 0);
      expect(
        source.metadataReads.where((id) => id.endsWith('.good')).length,
        1,
      );
    },
  );

  test(
    'installation changes preserve a failed refresh and its retry deadline',
    () async {
      var now = DateTime(2026, 10, 14);
      final host = _Host([_installed('com.example.found')]);
      final source = _Source();
      final store = _Store();
      final service = _service(host, source, store, now: () => now);
      addTearDown(service.dispose);
      await service.refresh();
      expect(service.updates.single.latest!.version, '2.0.0.1');

      source.onMetadata = (_) async => throw StateError('offline');
      await service.refresh(force: true);
      final retryAt = store.state.records.single.nextRetryAt;
      host.inventory = [
        _installed('com.example.found', version: '1.5', code: 2),
      ];
      source.onMetadata = (id) async => _details(id, version: '3.0');
      now = now.add(const Duration(minutes: 59));
      await service.refresh();
      expect(service.failedCount, 1);
      expect(store.state.records.single.nextRetryAt, retryAt);
      expect(source.metadataReads.length, 2);

      now = now.add(const Duration(minutes: 1));
      await service.refresh();
      expect(service.failedCount, 0);
      expect(service.updates.single.latest!.version, '3.0');
      expect(service.updates.single.installed!.versionName, '1.5');
      expect(source.metadataReads.length, 3);
    },
  );

  test(
    'bounds concurrent requests, deduplicates repeated refreshes, and recovers in-flight work',
    () async {
      final host = _Host([
        for (final suffix in ['one', 'two', 'three'])
          _installed('com.example.$suffix'),
      ]);
      final store = _Store();
      final gate = Completer<void>();
      final started = Completer<void>();
      var active = 0;
      final source = _Source()
        ..onMetadata = (id) async {
          active++;
          if (active == 2) started.complete();
          await gate.future;
          active--;
          return _details(id);
        };
      final service = _service(host, source, store);
      final first = service.refresh();
      await started.future;
      final second = service.refresh();
      expect(active, 2);
      expect(store.state.pendingKeys.toSet(), {
        for (final suffix in ['one', 'two', 'three'])
          'test\u0000package:com.example.$suffix',
      });
      final durable = store.state;
      service.dispose();
      gate.complete();
      await Future.wait([first, second]);
      expect(source.metadataReads.toSet().length, source.metadataReads.length);

      store.state = InstalledUpdateStoreState(
        records: [
          InstalledAppUpdateRecord(
            key: 'test\u0000package:com.example.one',
            sourceId: 'test',
            appId: 'https://source.test/apps/com.example.one',
            packageName: 'com.example.one',
            status: InstalledAppUpdateStatus.upToDate,
            checkedAt: DateTime.now(),
            installed: host.inventory.first,
            latest: _details(
              'https://source.test/apps/com.example.one',
              version: '1.0',
            ),
          ),
        ],
        pendingKeys: durable.pendingKeys,
      );
      final recoveredSource = _Source();
      final recovered = _service(host, recoveredSource, store);
      addTearDown(recovered.dispose);
      await recovered.refresh();
      expect(recovered.updates.map((record) => record.packageName).toSet(), {
        'com.example.one',
        'com.example.two',
        'com.example.three',
      });
      expect(recoveredSource.metadataReads.toSet(), {
        for (final suffix in ['one', 'two', 'three'])
          'https://source.test/apps/com.example.$suffix',
      });
      expect(store.state.pendingKeys, isEmpty);
    },
  );

  test(
    'cache expiry rechecks while explicit refresh bypasses a fresh cache',
    () async {
      var now = DateTime(2026, 10, 14);
      final host = _Host([_installed('com.example.found')]);
      final source = _Source();
      final service = _service(host, source, _Store(), now: () => now);
      addTearDown(service.dispose);
      await service.refresh();
      now = now.add(const Duration(hours: 23, minutes: 59));
      await service.refresh();
      expect(source.metadataReads.length, 1);
      now = now.add(const Duration(minutes: 1));
      await service.refresh();
      expect(source.metadataReads.length, 2);
      await service.refresh(force: true, manual: true);
      expect(source.metadataReads.length, 3);
    },
  );

  test(
    'disabled sources cannot publish late responses or start more requests',
    () async {
      final host = _Host([
        _installed('com.example.one'),
        _installed('com.example.two'),
        _installed('com.example.three'),
      ]);
      final started = Completer<void>();
      final gate = Completer<void>();
      final source = _Source()
        ..onMetadata = (id) async {
          if (!started.isCompleted) started.complete();
          await gate.future;
          return _details(id);
        };
      final service = _service(host, source, _Store());
      addTearDown(service.dispose);
      final refresh = service.refresh();
      await started.future;
      service.configure(downloads: [], enabledSourceIds: {}, automatic: true);
      gate.complete();
      await refresh;
      expect(service.updates, isEmpty);
      expect(
        source.metadataReads,
        isNot(contains('https://source.test/apps/com.example.three')),
      );
    },
  );

  test(
    'mismatched package and unparseable versions fail rather than suggesting a replacement',
    () async {
      final host = _Host([_installed('com.example.found')]);
      final source = _Source(packageInDetails: 'com.example.other');
      final store = _Store();
      final service = _service(host, source, store);
      addTearDown(service.dispose);
      await service.refresh();
      expect(service.updates, isEmpty);
      expect(store.state.records.single.error, contains('com.example.other'));
      source.onMetadata = (id) async =>
          _details(id, version: 'Varies with device');
      await service.refresh(force: true, manual: true);
      expect(service.updates, isEmpty);
      expect(service.failedCount, 1);
      expect(store.state.records.single.error, contains('Varies with device'));
    },
  );

  test(
    'automatic checks can pause and an explicit check still works',
    () async {
      final host = _Host([_installed('com.example.found')]);
      final source = _Source();
      final service = _service(host, source, _Store());
      addTearDown(service.dispose);
      service.configure(
        downloads: [],
        enabledSourceIds: {'test'},
        automatic: false,
      );
      await service.refresh();
      expect(source.lookups, isEmpty);
      await service.refresh(force: true, manual: true);
      expect(service.updates.single.packageName, 'com.example.found');
    },
  );
  test(
    'configuration changes cannot start requests before the pending checkpoint is saved',
    () async {
      final gate = Completer<void>();
      final store = _Store(beforeSave: gate.future);
      final source = _Source();
      final service = _service(
        _Host([_installed('com.example.found')]),
        source,
        store,
      );
      addTearDown(service.dispose);
      final refresh = service.refresh();
      await store.saveStarted.future;
      service.configure(
        downloads: [],
        enabledSourceIds: {'test'},
        automatic: true,
      );
      expect(source.lookups, isEmpty);
      gate.complete();
      await refresh;
      expect(service.updates.single.packageName, 'com.example.found');
      expect(store.state.pendingKeys, isEmpty);
    },
  );
}

InstalledAppUpdateService _service(
  _Host host,
  _Source source,
  _Store store, {
  List<DownloadTask> downloads = const [],
  DateTime Function()? now,
}) => InstalledAppUpdateService(
  host: host,
  registry: SourceRegistry(scripts: [source]),
  store: store,
  now: now,
)..configure(downloads: downloads, enabledSourceIds: {'test'}, automatic: true);

InstalledAppInfo _installed(
  String packageName, {
  String version = '1.0',
  int code = 1,
}) => InstalledAppInfo(
  packageName: packageName,
  versionName: version,
  versionCode: code,
);

AppDetails _details(
  String id, {
  String? packageName,
  String version = '2.0.0.1',
}) => AppDetails(
  id: id,
  sourceId: 'test',
  sourceName: 'Test source',
  name: 'Example',
  packageName: packageName ?? id.split('/').last,
  version: version,
  size: '',
  updatedAt: '',
  category: '',
  iconUrl: '',
  summary: '',
  description: '',
  screenshots: const [],
  comments: const [],
  downloads: const [],
);

final _download = DownloadTask(
  id: 'download',
  file: const SourceDownload(
    label: 'app.apk',
    url: 'https://source.test/app.apk',
    size: '',
  ),
  sourceId: 'test',
  status: DownloadStatus.completed,
  startedAt: DateTime(2026),
  filePath: '/cache/app.apk',
  app: _details('https://source.test/apps/com.example.found', packageName: ''),
);

class _Store implements InstalledUpdateStore {
  _Store({this.beforeSave});
  final Future<void>? beforeSave;
  final saveStarted = Completer<void>();
  InstalledUpdateStoreState state = const InstalledUpdateStoreState();
  @override
  Future<InstalledUpdateStoreState> load() async => state;
  @override
  Future<void> save(InstalledUpdateStoreState state) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await beforeSave;
    this.state = state;
  }
}

class _Host extends DemoHostApi {
  _Host(this.inventory);
  List<InstalledAppInfo> inventory;
  ApkInstallInfo? archive;
  int archiveReads = 0;
  @override
  Future<List<InstalledAppInfo>> installedApps() async => inventory;
  @override
  Future<ApkInstallInfo> inspectInstall(String filePath) async {
    archiveReads++;
    return archive ?? (throw StateError('APK removed'));
  }
}

class _Source
    implements
        ApkSourceScript,
        SourcePackageLookupScript,
        SourceDetailProgressScript {
  _Source({this.lookup = true, this.packageInDetails});
  final bool lookup;
  final String? packageInDetails;
  final missing = <String>{};
  final lookups = <String>[];
  final metadataReads = <String>[];
  Future<AppDetails> Function(String)? onMetadata;
  @override
  String get id => 'test';
  @override
  String get name => 'Test source';
  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {'source.test'});
  @override
  bool get supportsPackageLookup => lookup;
  @override
  Future<String?> packageLookupUrl(
    String packageName,
    SourceHostApi host,
  ) async {
    lookups.add(packageName);
    return missing.contains(packageName)
        ? null
        : 'https://source.test/apps/$packageName';
  }

  @override
  bool get supportsDetailProgress => true;
  @override
  Future<SourceDetailsMetadata> detailsMetadata(
    String appId,
    SourceHostApi host,
  ) async {
    metadataReads.add(appId);
    final details =
        await (onMetadata?.call(appId) ??
            Future.value(_details(appId, packageName: packageInDetails)));
    return SourceDetailsMetadata(details: details, downloads: const []);
  }

  @override
  Future<List<SourceDownload>> resolveDownloads(
    List<SourceDownloadCandidate> candidates,
    SourceHostApi host, {
    required void Function(int, List<SourceDownload>?, String?) onProgress,
  }) => throw StateError('Update checking must not resolve downloads');
  @override
  Future<AppDetails> details(String appId, SourceHostApi host) =>
      throw StateError('Use the metadata capability');
  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => const [];
  @override
  Future<void> dispose() async {}
}
