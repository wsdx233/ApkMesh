import 'dart:async';

import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('source policy only permits declared hosts', () {
    const policy = SourcePolicy(
      allowedHosts: {'example.com', '*.cdn.example.com'},
      allowBrowser: true,
    );

    expect(policy.permits(Uri.parse('https://example.com/app')), isTrue);
    expect(
      policy.permits(Uri.parse('https://img.cdn.example.com/icon.png')),
      isTrue,
    );
    expect(
      policy.permits(Uri.parse('https://cdn.example.com/icon.png')),
      isFalse,
    );
    expect(policy.permits(Uri.parse('file:///tmp/app.apk')), isFalse);
  });

  test('source policy allows an explicit any-host permission', () {
    const policy = SourcePolicy(allowedHosts: {'*'});

    expect(
      policy.permits(Uri.parse('https://temporary.example/file.apk')),
      isTrue,
    );
    expect(policy.permits(Uri.parse('http://redirect.example/file')), isTrue);
    expect(policy.permits(Uri.parse('file:///tmp/app.apk')), isFalse);
  });

  test('source policy only requires install capability for script calls', () {
    const undeclared = SourcePolicy(allowedHosts: {});
    const declared = SourcePolicy(allowedHosts: {}, allowInstall: true);

    expect(undeclared.permitsInstall(userInitiated: true), isTrue);
    expect(undeclared.permitsInstall(userInitiated: false), isFalse);
    expect(declared.permitsInstall(userInitiated: false), isTrue);
  });

  test('download task estimates remaining time from transfer speed', () {
    final task = DownloadTask(
      id: 'download-1',
      file: SourceDownload(
        label: 'example.apk',
        url: 'https://example.test/example.apk',
        size: '100 MB',
      ),
      sourceId: 'example-source',
      status: DownloadStatus.downloading,
      startedAt: DateTime(2026, 1, 1),
      received: 50 * 1024 * 1024,
      total: 100 * 1024 * 1024,
      speedBytesPerSecond: 10 * 1024 * 1024,
    );

    expect(task.progress, .5);
    expect(task.estimatedRemaining, const Duration(seconds: 5));
  });

  test('staged details publish metadata and per-candidate progress', () async {
    final registry = SourceRegistry(scripts: [_StagedDetailsSource()]);
    final updates = <AppDetailsProgress>[];

    await registry.loadDetails(
      _listing('staged', 'Staged App'),
      DemoHostApi(),
      onProgress: updates.add,
    );

    expect(updates, hasLength(4));
    expect(updates.first.phase, DetailLoadPhase.resolvingDownloads);
    expect(updates.first.details.name, 'Staged App');
    expect(updates.first.completedDownloads, 0);
    expect(updates[1].completedDownloads, 1);
    expect(updates[2].downloads.last.error, 'not found');
    expect(updates.last.phase, DetailLoadPhase.complete);
    expect(updates.last.details.downloads.single.label, 'app.apk');
  });

  test('app state caches details until a forced refresh', () async {
    final source = _StagedDetailsSource();
    final state = AppState(host: DemoHostApi());
    state.registry.replace(source);
    await state.initialize();
    final app = _listing('staged', 'Staged App');

    try {
      await state.loadDetails(app, onProgress: (_) {});
      final cachedUpdates = <AppDetailsProgress>[];
      await state.loadDetails(app, onProgress: cachedUpdates.add);

      expect(source.detailMetadataCalls, 1);
      expect(cachedUpdates, hasLength(1));
      expect(cachedUpdates.single.phase, DetailLoadPhase.complete);
      expect(cachedUpdates.single.details.downloads.single.label, 'app.apk');

      await state.loadDetails(app, forceRefresh: true, onProgress: (_) {});
      expect(source.detailMetadataCalls, 2);
    } finally {
      state.dispose();
    }
  });

  test(
    'batch app download resolves links without opening details UI',
    () async {
      final source = _StagedDetailsSource();
      final state = AppState(host: DemoHostApi());
      state.registry.replace(source);
      await state.initialize();
      final app = _listing('staged', 'Staged App');

      try {
        final result = await state.downloadApps([app, app]);

        expect(result.results, hasLength(1));
        expect(result.startedFiles, 1);
        expect(result.successfulApps, 1);
        expect(result.appsWithErrors, 1);
        expect(result.failedApps, isEmpty);
        expect(state.downloads.single.file.label, 'app.apk');
      } finally {
        state.dispose();
      }
    },
  );

  test('registry skips disabled source ids', () async {
    final registry = SourceRegistry(scripts: [ExampleCatalogSource()]);
    final host = DemoHostApi();

    expect(
      await registry.search('example', host, enabledSourceIds: const {}),
      isEmpty,
    );
    expect(
      (await registry.search(
        'example',
        host,
        enabledSourceIds: {'example-source'},
      )).single.name,
      'Example App',
    );
  });

  test(
    'registry starts all enabled searches before awaiting results',
    () async {
      final gate = _SearchGate();
      final registry = SourceRegistry(
        scripts: [
          _ConcurrentSource('first', gate),
          _ConcurrentSource('second', gate),
        ],
      );
      final completed = <String>[];
      final search = registry.search(
        'example',
        DemoHostApi(),
        onSourceCompleted: (source, _) => completed.add(source.id),
      );

      await gate.bothStarted.future;
      expect(gate.started, 2);
      expect(completed, isEmpty);

      gate.release.complete();
      final results = await search;
      expect(completed, hasLength(2));
      expect(results, hasLength(2));
    },
  );

  test('registry limits concurrently executing source operations', () async {
    final tracker = _ConcurrentTracker();
    final registry = SourceRegistry(
      maxConcurrentOperations: 2,
      scripts: List.generate(
        5,
        (index) => _LimitedConcurrentSource('limited-$index', tracker),
      ),
    );

    final search = registry.search('example', DemoHostApi());
    await tracker.firstWave.future;
    expect(tracker.started, 2);
    expect(tracker.peak, 2);

    tracker.release.complete();
    final results = await search;
    expect(results, hasLength(5));
    expect(tracker.peak, 2);
  });

  test('registry skips queued source operations after cancellation', () async {
    final tracker = _CancellationTracker();
    final cancellation = SourceSearchCancellation();
    final registry = SourceRegistry(
      maxConcurrentOperations: 1,
      scripts: List.generate(
        4,
        (index) => _CancellableSource('cancel-$index', tracker),
      ),
    );

    final search = registry.searchPage(
      'example',
      DemoHostApi(),
      cancellation: cancellation,
    );
    await tracker.firstStarted.future;
    cancellation.cancel();
    tracker.release.complete();
    await search;

    expect(tracker.started, 1);
  });

  test(
    'registry forwards pages and preserves an empty page as success',
    () async {
      final source = _PagedSource();
      final registry = SourceRegistry(scripts: [source]);

      final second = await registry.searchPage(
        'example',
        DemoHostApi(),
        page: 2,
        enabledSourceIds: {'paged'},
      );
      final third = await registry.searchPage(
        'example',
        DemoHostApi(),
        page: 3,
        enabledSourceIds: {'paged'},
        clearErrors: false,
      );

      expect(source.pages, [2, 3]);
      expect(second.single.page, 2);
      expect(second.single.results.single.name, 'Page 2');
      expect(third.single.page, 3);
      expect(third.single.results, isEmpty);
      expect(third.single.succeeded, isTrue);
      expect(registry.lastErrors, isEmpty);
    },
  );

  test(
    'registry ranks distinct title keywords and preserves source order on ties',
    () async {
      final registry = SourceRegistry(
        scripts: [
          _StaticSearchSource('first', [
            _listing('first', 'alpha beta normal'),
            _listing('first', 'alpha alpha beta repeated'),
            _listing('first', 'alpha only'),
          ]),
          _StaticSearchSource('second', [
            _listing('second', 'beta alpha second-source'),
            _listing('second', 'beta only'),
          ]),
        ],
      );

      final results = await registry.search('alpha beta', DemoHostApi());

      expect(results.map((app) => app.name), [
        'alpha beta normal',
        'alpha alpha beta repeated',
        'beta alpha second-source',
        'alpha only',
        'beta only',
      ]);
    },
  );

  test(
    'registry ranks exact match first even when returned by later source',
    () async {
      final registry = SourceRegistry(
        scripts: [
          _StaticSearchSource('first', [
            _listing('first', 'Guide for Telegram Messenger Pro'),
            _listing('first', 'Telegram Wallpaper HD Free'),
            _listing('first', 'Telegram Sticker Pack 2024'),
          ]),
          _StaticSearchSource('second', [
            _listing('second', 'Telegram'),
            _listing('second', 'Telegram X'),
          ]),
        ],
      );

      final results = await registry.search('Telegram', DemoHostApi());

      expect(results.first.name, 'Telegram');
      expect(results[1].name, 'Telegram X');
    },
  );

  test('registry ranks exact package name match first', () async {
    final registry = SourceRegistry(
      scripts: [
        _StaticSearchSource('first', [
          _listing(
            'first',
            'Guide for YouTube',
            packageName: 'com.guide.youtube',
          ),
          _listing(
            'first',
            'Tube Downloader',
            packageName: 'com.video.tubedownloader',
          ),
        ]),
        _StaticSearchSource('second', [
          _listing(
            'second',
            'YouTube',
            packageName: 'com.google.android.youtube',
          ),
        ]),
      ],
    );

    final results = await registry.search(
      'com.google.android.youtube',
      DemoHostApi(),
    );

    expect(results.first.name, 'YouTube');
    expect(results.first.packageName, 'com.google.android.youtube');
  });

  test(
    'registry penalizes spam derivative titles like guide and wallpaper',
    () async {
      final registry = SourceRegistry(
        scripts: [
          _StaticSearchSource('first', [
            _listing('first', 'Clash Guide & Tips'),
            _listing('first', 'Clash Wallpaper 4K'),
          ]),
          _StaticSearchSource('second', [
            _listing('second', 'Clash Meta'),
            _listing('second', 'Clash Verge'),
          ]),
        ],
      );

      final results = await registry.search('Clash', DemoHostApi());

      final topTwo = results.take(2).map((app) => app.name).toSet();
      expect(topTwo, containsAll(['Clash Meta', 'Clash Verge']));
    },
  );

  test(
    'registry ranks irrelevant apps with no matching keywords at the bottom',
    () async {
      final registry = SourceRegistry(
        scripts: [
          _StaticSearchSource('first', [
            _listing('first', 'Random Unrelated Browser'),
            _listing('first', 'Calculator Plus'),
          ]),
          _StaticSearchSource('second', [_listing('second', 'F-Droid Client')]),
        ],
      );

      final results = await registry.search('F-Droid', DemoHostApi());

      expect(results.first.name, 'F-Droid Client');
      expect(results.last.name, isNot('F-Droid Client'));
    },
  );

  test('registry loads source-defined catalog tabs and pages', () async {
    final registry = SourceRegistry(scripts: [ExampleCatalogSource()]);
    final catalog = await registry.catalog(
      DemoHostApi(),
      enabledSourceIds: {'example-source'},
    );

    expect(catalog.defaultTabId, 'featured');
    expect(catalog.tabs.map((tab) => tab.name), ['Featured', 'Tools']);
    expect(catalog.tabs.first.paged, isFalse);
    expect(catalog.tabs.last.paged, isTrue);

    final firstPage = await registry.catalogPage(
      catalog.tabs.last,
      DemoHostApi(),
    );
    final secondPage = await registry.catalogPage(
      catalog.tabs.last,
      DemoHostApi(),
      page: 2,
    );
    expect(firstPage.apps.single.name, 'Example App');
    expect(firstPage.hasMore, isTrue);
    expect(secondPage.apps, isEmpty);
    expect(secondPage.hasMore, isFalse);
  });

  test('registry exposes source failures for the UI', () async {
    final registry = SourceRegistry(scripts: [FailingSource()]);
    await registry.search(
      'example',
      DemoHostApi(),
      enabledSourceIds: {'failing'},
    );

    expect(registry.lastErrors['Failing source'], contains('parse failed'));
  });

  test(
    'registry looks up package names only through capable enabled source URLs',
    () async {
      final capable = _PackageSource('capable', supports: true);
      final incapable = _PackageSource('incapable', supports: false);
      final registry = SourceRegistry(scripts: [capable, incapable]);

      final results = await registry.lookupByPackageName(
        'test.example.app',
        DemoHostApi(),
        enabledSourceIds: {'capable', 'incapable'},
      );

      expect(results.map((app) => app.sourceId), ['example-source']);
      expect(capable.urlLookups, 1);
      expect(capable.detailLookups, 1);
      expect(incapable.urlLookups, 0);
      expect(incapable.detailLookups, 0);
    },
  );
}

class ExampleCatalogSource implements ApkSourceScript, SourceCatalogScript {
  @override
  String get id => 'example-source';

  @override
  String get name => 'Example source';

  @override
  SourcePolicy get policy =>
      const SourcePolicy(allowedHosts: {'example.test', '*.cdn.example.test'});

  @override
  bool get supportsCatalog => true;

  @override
  Future<SourceCatalog> catalog(SourceHostApi host) async => SourceCatalog(
    defaultTabId: 'featured',
    tabs: [
      SourceCatalogTab(
        id: 'featured',
        name: 'Featured',
        sourceId: id,
        sourceName: name,
        paged: false,
      ),
      SourceCatalogTab(
        id: 'tools',
        name: 'Tools',
        sourceId: id,
        sourceName: name,
        paged: true,
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
    apps: page == 1 ? const [_app] : const [],
    hasMore: tabId == 'tools' && page == 1,
  );

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    if (!query.toLowerCase().contains('example')) return const [];
    return const [_app];
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async => _app;

  @override
  Future<void> dispose() async {}

  static const _app = AppDetails(
    id: 'https://example.test/apps/example',
    sourceId: 'example-source',
    name: 'Example App',
    packageName: 'test.example.app',
    version: '1.0.0',
    size: '1 MB',
    updatedAt: '2026-01-01',
    category: 'Tools',
    sourceName: 'Example source',
    iconUrl: 'https://cdn.example.test/example.png',
    summary: 'Example listing',
    description: 'Example details',
    screenshots: [],
    comments: [],
    downloads: [],
  );
}

class _PackageSource implements ApkSourceScript, SourcePackageLookupScript {
  _PackageSource(this.id, {required this.supports});

  @override
  final String id;
  final bool supports;
  int urlLookups = 0;
  int detailLookups = 0;

  @override
  String get name => 'Package $id';

  @override
  bool get supportsPackageLookup => supports;

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<String?> packageLookupUrl(
    String packageName,
    SourceHostApi host,
  ) async {
    urlLookups += 1;
    return supports ? 'https://example.test/apps/example' : null;
  }

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => const [];

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    detailLookups += 1;
    return ExampleCatalogSource._app;
  }

  @override
  Future<void> dispose() async {}
}

class _PagedSource implements ApkSourceScript {
  final pages = <int>[];

  @override
  String get id => 'paged';

  @override
  String get name => 'Paged source';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    pages.add(page);
    return switch (page) {
      2 => [_listing(id, 'Page 2')],
      _ => const [],
    };
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}

class _StaticSearchSource implements ApkSourceScript {
  _StaticSearchSource(this.id, this.results);

  @override
  final String id;
  final List<AppListing> results;

  @override
  String get name => 'Static $id';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => results;

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}

AppListing _listing(String sourceId, String name, {String packageName = ''}) =>
    AppListing(
      id: '$sourceId/$name',
      sourceId: sourceId,
      name: name,
      packageName: packageName,
      version: '',
      size: '',
      updatedAt: '',
      category: '',
      sourceName: sourceId,
      iconUrl: '',
    );

class _SearchGate {
  int started = 0;
  final bothStarted = Completer<void>();
  final release = Completer<void>();
}

class _ConcurrentSource implements ApkSourceScript {
  _ConcurrentSource(this.id, this.gate);

  @override
  final String id;
  final _SearchGate gate;

  @override
  String get name => 'Concurrent $id';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    gate.started += 1;
    if (gate.started == 2) gate.bothStarted.complete();
    await gate.release.future;
    return const [ExampleCatalogSource._app];
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async =>
      ExampleCatalogSource._app;

  @override
  Future<void> dispose() async {}
}

class _ConcurrentTracker {
  int active = 0;
  int started = 0;
  int peak = 0;
  final firstWave = Completer<void>();
  final release = Completer<void>();
}

class _LimitedConcurrentSource implements ApkSourceScript {
  _LimitedConcurrentSource(this.id, this.tracker);

  @override
  final String id;
  final _ConcurrentTracker tracker;

  @override
  String get name => id;

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    tracker.active += 1;
    tracker.started += 1;
    if (tracker.active > tracker.peak) tracker.peak = tracker.active;
    if (tracker.started == 2) tracker.firstWave.complete();
    try {
      await tracker.release.future;
      return [_listing(id, name)];
    } finally {
      tracker.active -= 1;
    }
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async =>
      ExampleCatalogSource._app;

  @override
  Future<void> dispose() async {}
}

class _CancellationTracker {
  int started = 0;
  final firstStarted = Completer<void>();
  final release = Completer<void>();
}

class _CancellableSource implements ApkSourceScript {
  _CancellableSource(this.id, this.tracker);

  @override
  final String id;
  final _CancellationTracker tracker;

  @override
  String get name => id;

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async {
    tracker.started += 1;
    if (!tracker.firstStarted.isCompleted) tracker.firstStarted.complete();
    await tracker.release.future;
    return [_listing(id, name)];
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async =>
      ExampleCatalogSource._app;

  @override
  Future<void> dispose() async {}
}

class _StagedDetailsSource
    implements ApkSourceScript, SourceDetailProgressScript {
  static const _detail = AppDetails(
    id: 'staged/app',
    sourceId: 'staged',
    name: 'Staged App',
    packageName: 'com.example.staged',
    version: '1.0.0',
    size: '1 MB',
    updatedAt: '2026-01-01',
    category: 'Tools',
    sourceName: 'Staged source',
    iconUrl: '',
    summary: '',
    screenshots: [],
    comments: [],
    downloads: [],
  );

  @override
  String get id => 'staged';

  @override
  String get name => 'Staged source';

  @override
  SourcePolicy get policy =>
      const SourcePolicy(allowedHosts: {'example.test'}, allowDownload: true);

  @override
  bool get supportsDetailProgress => true;

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) async => const [];

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) async => _detail;

  int detailMetadataCalls = 0;

  @override
  Future<SourceDetailsMetadata> detailsMetadata(
    String appId,
    SourceHostApi host,
  ) async {
    detailMetadataCalls += 1;
    return SourceDetailsMetadata(
      details: _detail,
      downloads: const [
        SourceDownloadCandidate(
          label: 'Primary',
          url: 'https://example.test/primary',
          size: '1 MB',
        ),
        SourceDownloadCandidate(
          label: 'Missing',
          url: 'https://example.test/missing',
          size: '1 MB',
        ),
      ],
    );
  }

  @override
  Future<List<SourceDownload>> resolveDownloads(
    List<SourceDownloadCandidate> candidates,
    SourceHostApi host, {
    required void Function(
      int index,
      List<SourceDownload>? files,
      String? error,
    )
    onProgress,
  }) async {
    const file = SourceDownload(
      label: 'app.apk',
      url: 'https://example.test/app.apk',
      size: '1 MB',
    );
    onProgress(0, const [file], null);
    onProgress(1, const [], 'not found');
    return const [file];
  }

  @override
  Future<void> dispose() async {}
}

class FailingSource implements ApkSourceScript {
  @override
  String get id => 'failing';

  @override
  String get name => 'Failing source';

  @override
  SourcePolicy get policy => const SourcePolicy(allowedHosts: {});

  @override
  Future<List<AppListing>> search(
    String query,
    SourceHostApi host, {
    int page = 1,
  }) {
    throw StateError('parse failed');
  }

  @override
  Future<AppDetails> details(String appId, SourceHostApi host) {
    throw StateError('parse failed');
  }

  @override
  Future<void> dispose() async {}
}
