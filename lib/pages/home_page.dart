import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/source_runtime.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_result_tile.dart';
import '../widgets/empty_message.dart';
import 'details_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.state,
    required this.controller,
    this.onSearchLoadingChanged,
    this.onPageJumpAvailabilityChanged,
    super.key,
  });

  final AppState state;
  final TextEditingController controller;
  final ValueChanged<bool>? onSearchLoadingChanged;
  final ValueChanged<bool>? onPageJumpAvailabilityChanged;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const _horizontalContentPadding = 24.0;
  static const _filterButtonExtent = 48.0;
  static const _tabLabelHorizontalPadding = 32.0;

  List<AppListing> results = const [];
  SourceCatalog catalog = const SourceCatalog();
  bool loading = false;
  bool loadingMore = false;
  bool catalogLoading = false;
  bool catalogLoaded = false;
  String? error;
  String? catalogError;
  String? submittedQuery;
  String _selectedTab = '';
  String? _previewSourceId;
  String? _loadedCatalogSourceId;
  final Map<String, _CatalogTabLoadState> _catalogTabStates = {};
  int _searchGeneration = 0;
  int _catalogGeneration = 0;
  SearchResultRanker? _searchRanker;
  Map<String, int> _searchSourceOrder = const {};
  Map<String, Map<String, int>> _searchResultOrder = {};
  Set<String> _searchSourceIds = const {};
  Set<String> _searchExhaustedSources = {};
  Set<String> _searchFailedSources = {};
  Map<String, String> _searchPageErrors = {};
  String? _lastShownSearchError;
  int _nextSearchPage = 2;
  bool _selectionMode = false;
  final Map<String, AppListing> _selectedApps = {};
  final List<AppListing> _pendingSearchResults = [];
  Timer? _searchMergeTimer;
  SourceSearchCancellation? _searchCancellation;
  late final ScrollController _contentScrollController;

  @override
  void initState() {
    super.initState();
    _contentScrollController = ScrollController()
      ..addListener(_onContentScroll);
    widget.state.addListener(_onStateChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCancellation?.cancel();
    _searchMergeTimer?.cancel();
    widget.state.removeListener(_onStateChanged);
    _contentScrollController
      ..removeListener(_onContentScroll)
      ..dispose();
    super.dispose();
  }

  String _appKey(AppListing app) => '${app.sourceId}\u0000${app.id}';

  bool _isSelected(AppListing app) => _selectedApps.containsKey(_appKey(app));

  void _enterSelection(AppListing app) {
    setState(() {
      _selectionMode = true;
      _selectedApps[_appKey(app)] = app;
    });
  }

  void _toggleSelection(AppListing app) {
    final key = _appKey(app);
    setState(() {
      if (_selectedApps.remove(key) == null) {
        _selectedApps[key] = app;
      }
    });
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedApps.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedApps.clear();
    });
  }

  void _favoriteSelected() {
    final apps = _selectedApps.values.toList(growable: false);
    final added = widget.state.favoriteApps(apps);
    _exitSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? AppLocalizations.of(context).alreadyFavorites
                : AppLocalizations.of(
                    context,
                  ).appsFavorited((added).toString()),
          ),
        ),
      );
  }

  void _downloadSelected() {
    final apps = _selectedApps.values.toList(growable: false);
    if (apps.isEmpty) return;
    _exitSelection();
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).resolvingDownloadsBackground,
          ),
        ),
      );
    unawaited(_runBatchDownload(apps, messenger));
  }

  Future<void> _runBatchDownload(
    List<AppListing> apps,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final result = await widget.state.downloadApps(apps);
      if (!mounted || !messenger.mounted) return;
      final failed = result.appsWithErrors;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.startedFiles == 0
                  ? AppLocalizations.of(context).batchDownloadNoLinks
                  : failed == 0
                  ? AppLocalizations.of(
                      context,
                    ).filesStarted((result.startedFiles).toString())
                  : AppLocalizations.of(context).filesStartedWithErrors(
                      (result.startedFiles).toString(),
                      (failed).toString(),
                    ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted || !messenger.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).batchDownloadFailed((error).toString()),
            ),
          ),
        );
    }
  }

  void _onStateChanged() {
    if (!mounted || submittedQuery != null) return;
    if (_loadedCatalogSourceId == widget.state.homeSourceId) return;
    _catalogTabStates.clear();
    setState(() {
      catalog = const SourceCatalog();
      catalogLoaded = false;
      catalogLoading = false;
      _selectedTab = '';
      _selectionMode = false;
      _selectedApps.clear();
    });
    _notifyPageJumpAvailabilityChanged();
    _loadCatalog();
  }

  Future<void> _loadCatalog({bool force = false}) async {
    if ((catalogLoaded && !force) || catalogLoading) return;
    if (force) _catalogTabStates.clear();
    final generation = ++_catalogGeneration;
    setState(() {
      catalogLoading = true;
      catalogError = null;
    });
    try {
      final content = await widget.state.catalog();
      if (!mounted || generation != _catalogGeneration) return;
      final selected = _selectCatalogTab(content);
      setState(() {
        catalog = content;
        _loadedCatalogSourceId = widget.state.homeSourceId;
        catalogLoading = false;
        catalogLoaded = true;
        _selectedTab = selected == null ? '' : _catalogTabKey(selected);
        if (content.tabs.isEmpty && widget.state.sourceErrors.isNotEmpty) {
          catalogError = widget.state.sourceErrors.entries
              .map((entry) => '${entry.key}：${entry.value}')
              .join('\n');
        }
      });
      _notifyPageJumpAvailabilityChanged();
      if (selected != null) await _loadCatalogTab(selected);
    } catch (loadError) {
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        catalogLoading = false;
        catalogLoaded = true;
        catalogError = loadError.toString();
      });
    }
  }

  SourceCatalogTab? _selectCatalogTab(SourceCatalog content) {
    for (final tab in content.tabs) {
      if (_catalogTabKey(tab) == _selectedTab) return tab;
    }
    for (final tab in content.tabs) {
      if (tab.id == content.defaultTabId) return tab;
    }
    return content.tabs.firstOrNull;
  }

  String _catalogTabKey(SourceCatalogTab tab) =>
      'catalog:${tab.sourceId}:${tab.id}';

  Future<void> _loadCatalogTab(
    SourceCatalogTab tab, {
    bool refresh = false,
    int? targetPage,
  }) async {
    final key = _catalogTabKey(tab);
    final state = _catalogTabStates.putIfAbsent(
      key,
      () => _CatalogTabLoadState(),
    );
    if (state.loading ||
        (targetPage == null && !refresh && state.loaded && !state.hasMore)) {
      return;
    }
    if (targetPage == null && !refresh && state.loaded && !tab.paged) return;

    final generation = _catalogGeneration;
    final page = targetPage ?? (refresh ? 1 : state.nextPage);
    final replaceApps = refresh || targetPage != null;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    try {
      final result = await widget.state.catalogPage(tab, page: page);
      if (!mounted || generation != _catalogGeneration) return;
      final seenIds = replaceApps ? <String>{} : state.seenIds;
      final newApps = <AppListing>[];
      for (final app in result.apps) {
        if (seenIds.add(app.id)) newApps.add(app);
      }
      setState(() {
        if (replaceApps) {
          state.seenIds
            ..clear()
            ..addAll(seenIds);
        }
        state
          ..apps = replaceApps ? newApps : [...state.apps, ...newApps]
          ..loaded = true
          ..currentPage = page
          ..nextPage = page + 1
          ..hasMore = tab.paged && result.hasMore && newApps.isNotEmpty
          ..error = null;
      });
      if (targetPage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _contentScrollController.hasClients) {
            _contentScrollController.jumpTo(0);
          }
        });
      }
    } catch (loadError) {
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        state
          ..loaded = true
          ..error = loadError.toString();
      });
    } finally {
      if (mounted && generation == _catalogGeneration) {
        setState(() => state.loading = false);
      }
    }
  }

  Future<void> search({bool preserveSelectedTab = false}) async {
    final query = widget.controller.text.trim();
    final refreshTab = preserveSelectedTab ? _activeTab(_tabs) : null;
    if (!preserveSelectedTab) _previewSourceId = null;
    final sourceId = refreshTab?.sourceId;
    final sourceIds = sourceId == null ? null : {sourceId};
    final generation = ++_searchGeneration;
    _searchCancellation?.cancel();
    final cancellation = SourceSearchCancellation();
    _searchCancellation = cancellation;
    _searchRanker = null;
    _searchSourceOrder = const {};
    _searchResultOrder = {};
    _searchSourceIds =
        (sourceIds ??
                widget.state.sources
                    .where((source) => source.status == SourceStatus.enabled)
                    .map((source) => source.id))
            .toSet();
    _searchExhaustedSources = {};
    _searchFailedSources = {};
    _searchPageErrors = {};
    _lastShownSearchError = null;
    _nextSearchPage = 2;
    _searchMergeTimer?.cancel();
    _searchMergeTimer = null;
    _pendingSearchResults.clear();
    loadingMore = false;
    if (query.isEmpty) {
      final selected = _selectCatalogTab(catalog);
      setState(() {
        submittedQuery = null;
        results = const [];
        loading = false;
        error = null;
        _selectedTab = selected == null ? '' : _catalogTabKey(selected);
      });
      _notifyPageJumpAvailabilityChanged();
      widget.onSearchLoadingChanged?.call(false);
      _searchCancellation = null;
      if (_loadedCatalogSourceId != widget.state.homeSourceId) {
        await _loadCatalog(force: true);
      } else if (selected != null) {
        await _loadCatalogTab(selected);
      }
      return;
    }
    _searchRanker = SearchResultRanker(query);
    _searchSourceOrder = {
      for (var index = 0; index < widget.state.sources.length; index++)
        widget.state.sources[index].id: index,
    };
    _searchResultOrder = {};
    setState(() {
      loading = true;
      error = null;
      results = const [];
      submittedQuery = query;
      _selectedTab = refreshTab?.id ?? 'all';
    });
    _notifyPageJumpAvailabilityChanged();
    widget.onSearchLoadingChanged?.call(true);
    try {
      final pages = await widget.state.searchPage(
        query,
        page: 1,
        sourceIds: sourceIds,
        cancellation: cancellation,
        onSourcePage: (page) {
          if (!mounted || generation != _searchGeneration) return;
          _handleSearchPage(page);
        },
      );
      if (mounted && generation == _searchGeneration) {
        _flushSearchResults();
        final found = pages.fold<int>(
          0,
          (total, page) => total + page.results.length,
        );
        final searchError = _searchPageErrors.isNotEmpty
            ? _formatSearchPageErrors()
            : found == 0 && widget.state.sourceErrors.isNotEmpty
            ? widget.state.sourceErrors.entries
                  .map((entry) => '${entry.key}：${entry.value}')
                  .join('\n')
            : null;
        setState(() {
          loading = false;
          error = searchError;
        });
        if (searchError != null) _showSearchErrorSnackBar(searchError);
        widget.onSearchLoadingChanged?.call(false);
      }
    } catch (searchError) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          loading = false;
          error = searchError.toString();
        });
        _showSearchErrorSnackBar(searchError.toString());
        widget.onSearchLoadingChanged?.call(false);
      }
    }
  }

  void _handleSearchPage(SourceSearchPage page) {
    final newResults = _collectSearchPageResults(page);
    if (newResults.isEmpty) return;
    _pendingSearchResults.addAll(newResults);
    _searchMergeTimer ??= Timer(
      const Duration(milliseconds: 16),
      _flushSearchResults,
    );
  }

  List<AppListing> _collectSearchPageResults(SourceSearchPage page) {
    if (!page.succeeded) {
      _searchFailedSources.add(page.sourceId);
      _searchPageErrors[page.sourceId] = page.error!;
      return const [];
    }
    if (page.results.isEmpty) {
      _searchExhaustedSources.add(page.sourceId);
      return const [];
    }

    final resultOrder = _searchResultOrder.putIfAbsent(
      page.sourceId,
      () => <String, int>{},
    );
    final newResults = <AppListing>[];
    for (final app in page.results) {
      if (resultOrder.containsKey(app.id)) continue;
      resultOrder[app.id] = resultOrder.length;
      newResults.add(app);
    }
    if (newResults.isEmpty) _searchExhaustedSources.add(page.sourceId);
    return newResults;
  }

  String _formatSearchPageErrors() => _searchPageErrors.entries
      .map((entry) => '${entry.key}：${entry.value}')
      .join('\n');

  void _showSearchErrorSnackBar(String message) {
    if (!mounted || message.isEmpty || message == _lastShownSearchError) {
      return;
    }
    _lastShownSearchError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).searchSourcesFailed),
          action: SnackBarAction(
            label: AppLocalizations.of(context).details,
            onPressed: () => _showSearchErrorDetails(message),
          ),
        ),
      );
    });
  }

  void _showSearchErrorDetails(String message) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SearchErrorSheet(message: message),
    );
  }

  bool get _hasSearchSourcesToLoad => _searchSourceIds.any(
    (sourceId) =>
        !_searchExhaustedSources.contains(sourceId) &&
        !_searchFailedSources.contains(sourceId),
  );

  void _onContentScroll() {
    if (!_contentScrollController.hasClients ||
        _contentScrollController.position.extentAfter > 480) {
      return;
    }
    if (submittedQuery != null) {
      if (!loading && !loadingMore) unawaited(_loadNextSearchPage());
      return;
    }
    final tab = _activeTab(_tabs)?.catalogTab;
    if (tab == null || !tab.paged) return;
    final state = _catalogTabStates[_catalogTabKey(tab)];
    if (state == null || state.loading || !state.hasMore) return;
    unawaited(_loadCatalogTab(tab));
  }

  Future<void> _loadNextSearchPage() async {
    if (loading || loadingMore || !_hasSearchSourcesToLoad) return;
    final generation = _searchGeneration;
    final sourceIds = _searchSourceIds
        .where(
          (sourceId) =>
              !_searchExhaustedSources.contains(sourceId) &&
              !_searchFailedSources.contains(sourceId),
        )
        .toSet();
    if (sourceIds.isEmpty) return;

    final page = _nextSearchPage++;
    setState(() => loadingMore = true);
    try {
      final pages = await widget.state.searchPage(
        submittedQuery!,
        page: page,
        sourceIds: sourceIds,
        cancellation: _searchCancellation,
      );
      if (!mounted || generation != _searchGeneration) return;
      final newResults = <AppListing>[];
      for (final result in pages) {
        newResults.addAll(_collectSearchPageResults(result));
      }
      _appendSearchResults(newResults);
      if (_searchPageErrors.isNotEmpty) {
        final searchError = _formatSearchPageErrors();
        setState(() => error = searchError);
        _showSearchErrorSnackBar(searchError);
      }
    } catch (loadError) {
      if (mounted && generation == _searchGeneration) {
        final message = loadError.toString();
        setState(() => error = message);
        _showSearchErrorSnackBar(message);
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => loadingMore = false);
      }
    }
  }

  void _appendSearchResults(List<AppListing> newResults) {
    if (newResults.isEmpty) return;
    final sortedResults = [...newResults]..sort(_compareSearchResults);
    setState(() => results = [...results, ...sortedResults]);
  }

  int _compareSearchResults(AppListing left, AppListing right) {
    final ranker = _searchRanker;
    if (ranker == null) return 0;

    return ranker.compare(
      left,
      right,
      tieBreaker: (l, r) {
        const fallbackOrder = 1 << 30;
        final leftResultOrder =
            _searchResultOrder[l.sourceId]?[l.id] ?? fallbackOrder;
        final rightResultOrder =
            _searchResultOrder[r.sourceId]?[r.id] ?? fallbackOrder;
        final resultOrder = leftResultOrder.compareTo(rightResultOrder);
        if (resultOrder != 0) return resultOrder;

        final sourceOrder = (_searchSourceOrder[l.sourceId] ?? fallbackOrder)
            .compareTo(_searchSourceOrder[r.sourceId] ?? fallbackOrder);
        return sourceOrder;
      },
    );
  }

  void _mergeRegisteredSearchResults(List<AppListing> newResults) {
    if (newResults.isEmpty) return;
    final merged = [...results, ...newResults]..sort(_compareSearchResults);
    setState(() => results = merged);
  }

  void _flushSearchResults() {
    _searchMergeTimer?.cancel();
    _searchMergeTimer = null;
    if (!mounted || _pendingSearchResults.isEmpty) return;
    final pending = List<AppListing>.of(_pendingSearchResults);
    _pendingSearchResults.clear();
    _mergeRegisteredSearchResults(pending);
  }

  void showHome() {
    ++_searchGeneration;
    _searchCancellation?.cancel();
    _searchCancellation = null;
    _searchMergeTimer?.cancel();
    _searchMergeTimer = null;
    _pendingSearchResults.clear();
    final selected = _selectCatalogTab(catalog);
    setState(() {
      submittedQuery = null;
      results = const [];
      loading = false;
      loadingMore = false;
      error = null;
      _selectedTab = selected == null ? '' : _catalogTabKey(selected);
      _previewSourceId = null;
    });
    _notifyPageJumpAvailabilityChanged();
    widget.onSearchLoadingChanged?.call(false);
    if (_loadedCatalogSourceId != widget.state.homeSourceId) {
      _loadCatalog(force: true);
    } else if (selected != null) {
      _loadCatalogTab(selected);
    } else {
      _loadCatalog();
    }
  }

  Future<void> _refreshContent() async {
    final activeTab = _activeTab(_tabs);
    if (submittedQuery != null) {
      await search(preserveSelectedTab: true);
      return;
    }
    final catalogTab = activeTab?.catalogTab;
    if (catalogTab != null) await _loadCatalogTab(catalogTab, refresh: true);
  }

  List<ContentTab> get _tabs {
    if (submittedQuery == null) {
      return catalog.tabs
          .map(
            (tab) => ContentTab(
              id: _catalogTabKey(tab),
              label: tab.name,
              catalogTab: tab,
            ),
          )
          .toList(growable: false);
    }
    return [
      ContentTab(id: 'all', label: AppLocalizations.of(context).allSources),
      for (final source in widget.state.sources)
        if (source.status == SourceStatus.enabled) _sourceTab(source),
    ];
  }

  List<ContentTab> _visibleSearchTabs(BuildContext context, double maxWidth) {
    final allTab = ContentTab(
      id: 'all',
      label: AppLocalizations.of(context).allSources,
    );
    final enabledSources = widget.state.sources
        .where((source) => source.status == SourceStatus.enabled)
        .toList(growable: false);
    final sourcesById = {
      for (final source in enabledSources) source.id: source,
    };
    final fixedSources = <ApkSource>[];
    final addedIds = <String>{};
    for (final sourceId in widget.state.searchTabSourceIds) {
      final source = sourcesById[sourceId];
      if (source != null && addedIds.add(source.id)) fixedSources.add(source);
    }
    final previewSource = sourcesById[_previewSourceId];
    if (previewSource != null && addedIds.add(previewSource.id)) {
      fixedSources.add(previewSource);
    }

    final tabs = <ContentTab>[allTab];
    var usedWidth = _searchTabWidth(context, allTab.label);
    for (final source in fixedSources) {
      tabs.add(_sourceTab(source));
      usedWidth += _searchTabWidth(context, source.name);
    }
    for (final source in enabledSources) {
      if (!addedIds.add(source.id)) continue;
      final width = _searchTabWidth(context, source.name);
      if (tabs.length > 1 && usedWidth + width > maxWidth) break;
      tabs.add(_sourceTab(source));
      usedWidth += width;
    }
    return tabs;
  }

  ContentTab _sourceTab(ApkSource source) => ContentTab(
    id: 'source:${source.id}',
    label: source.name,
    sourceId: source.id,
  );

  double _searchTabWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width + _tabLabelHorizontalPadding;
  }

  ContentTab? _activeTab(List<ContentTab> tabs) {
    for (final tab in tabs) {
      if (tab.id == _selectedTab) return tab;
    }
    return tabs.firstOrNull;
  }

  void _notifyPageJumpAvailabilityChanged() {
    final activeTab = _activeTab(_tabs)?.catalogTab;
    widget.onPageJumpAvailabilityChanged?.call(
      submittedQuery == null && activeTab?.paged == true,
    );
  }

  Future<void> showPageJumpDialog() async {
    final tab = _activeTab(_tabs)?.catalogTab;
    if (submittedQuery != null || tab == null || !tab.paged) return;
    final tabKey = _catalogTabKey(tab);
    final targetPage = await showDialog<int>(
      context: context,
      builder: (_) => _PageJumpDialog(
        initialPage: _catalogTabStates[tabKey]?.currentPage ?? 1,
      ),
    );
    if (!mounted || targetPage == null) return;
    final currentTab = _activeTab(_tabs)?.catalogTab;
    if (currentTab == null || _catalogTabKey(currentTab) != tabKey) return;
    await _loadCatalogTab(tab, targetPage: targetPage);
  }

  Widget _buildTabBar(
    BuildContext context,
    List<ContentTab> tabs,
    ContentTab activeTab,
  ) {
    final tabKey = tabs.map((tab) => tab.id).join('|');
    final activeIndex = tabs.indexWhere((tab) => tab.id == activeTab.id);
    final tabBar = DefaultTabController(
      key: ValueKey(tabKey),
      length: tabs.length,
      initialIndex: activeIndex < 0 ? 0 : activeIndex,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: (index) {
          if (index < tabs.length) {
            final tab = tabs[index];
            setState(() => _selectedTab = tab.id);
            _notifyPageJumpAvailabilityChanged();
            if (tab.catalogTab != null) {
              unawaited(_loadCatalogTab(tab.catalogTab!));
            }
          }
        },
        tabs: tabs.map((tab) => Tab(text: tab.label)).toList(),
      ),
    );
    if (submittedQuery == null) return tabBar;
    return Row(
      children: [
        Expanded(child: tabBar),
        IconButton(
          tooltip: AppLocalizations.of(context).filterSearchSources,
          onPressed: _showSourcePicker,
          icon: const Icon(Icons.filter_list),
        ),
      ],
    );
  }

  Future<void> _showSourcePicker() async {
    final sources = widget.state.sources
        .where((source) => source.status == SourceStatus.enabled)
        .toList(growable: false);
    final result = await showModalBottomSheet<_SourcePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SourcePickerSheet(
        sources: sources,
        selectedSourceIds: widget.state.searchTabSourceIds,
      ),
    );
    if (!mounted || result == null) return;
    final previewSourceId = result.previewSourceId;
    if (previewSourceId != null) {
      setState(() {
        _previewSourceId = previewSourceId;
        _selectedTab = 'source:$previewSourceId';
      });
      return;
    }
    widget.state.setSearchTabSourceIds(result.selectedSourceIds!);
    setState(() => _previewSourceId = null);
  }

  Widget _buildStaticContent(List<Widget> children) => ListView(
    controller: _contentScrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
    children: children,
  );

  Widget _buildCatalogView(BuildContext context, ContentTab? activeTab) {
    if (!widget.state.hasEnabledSource) {
      return _buildStaticContent([
        EmptyMessage(
          icon: Icons.hub_outlined,
          title: AppLocalizations.of(context).noEnabledSources,
          detail: AppLocalizations.of(context).noEnabledSourcesHint,
        ),
      ]);
    }
    if (catalogLoading && !catalogLoaded) {
      return _buildStaticContent([
        SearchLoadingView(
          icon: Icons.home_outlined,
          label: AppLocalizations.of(context).loadingHome,
        ),
      ]);
    }
    if (catalogError != null && catalog.tabs.isEmpty) {
      return _buildStaticContent([
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(AppLocalizations.of(context).homeLoadFailed),
            subtitle: Text(catalogError!),
            trailing: IconButton(
              tooltip: AppLocalizations.of(context).retry,
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadCatalog(force: true),
            ),
          ),
        ),
      ]);
    }
    final tab = activeTab?.catalogTab;
    if (tab == null) {
      return _buildStaticContent([
        EmptyMessage(
          icon: Icons.home_work_outlined,
          title: AppLocalizations.of(context).noCatalog,
          detail: AppLocalizations.of(context).noCatalogHint,
        ),
      ]);
    }
    final state = _catalogTabStates[_catalogTabKey(tab)];
    if (state == null || (state.loading && !state.loaded)) {
      return _buildStaticContent([
        SearchLoadingView(
          icon: Icons.apps_outlined,
          label: AppLocalizations.of(
            context,
          ).loadingNamed((tab.name).toString()),
        ),
      ]);
    }
    if (state.error != null && state.apps.isEmpty) {
      return _buildStaticContent([
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(
              AppLocalizations.of(
                context,
              ).namedLoadFailed((tab.name).toString()),
            ),
            subtitle: Text(state.error!),
            trailing: IconButton(
              tooltip: AppLocalizations.of(context).retry,
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadCatalogTab(tab, refresh: true),
            ),
          ),
        ),
      ]);
    }
    if (state.apps.isEmpty) {
      return _buildStaticContent([
        EmptyMessage(
          icon: Icons.apps_outage_outlined,
          title: AppLocalizations.of(context).noApps,
          detail: AppLocalizations.of(context).noAppsHint,
        ),
      ]);
    }
    final hasFooter = state.loading || state.error != null;
    return ListView.builder(
      controller: _contentScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      itemCount: state.apps.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < state.apps.length) {
          return AppResultTile(
            key: ValueKey(
              '${state.apps[index].sourceId}:${state.apps[index].id}',
            ),
            app: state.apps[index],
            state: widget.state,
            onOpen: (app) => showAppDetails(context, widget.state, app),
            onEnterSelection: _enterSelection,
            onSelect: _toggleSelection,
            selectionMode: _selectionMode,
            selected: _isSelected(state.apps[index]),
            showDivider: index < state.apps.length - 1,
          );
        }
        if (state.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(AppLocalizations.of(context).nextPageFailed),
          trailing: IconButton(
            tooltip: AppLocalizations.of(context).retry,
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCatalogTab(tab),
          ),
        );
      },
    );
  }

  Widget _buildSearchEmpty(BuildContext context, ContentTab activeTab) {
    if (loading) return const SearchLoadingView();
    return EmptyMessage(
      icon: Icons.manage_search,
      title: AppLocalizations.of(context).noResults,
      detail: error == null
          ? activeTab.sourceId == null
                ? AppLocalizations.of(
                    context,
                  ).searchedAllSources((submittedQuery).toString())
                : AppLocalizations.of(
                    context,
                  ).noSourceResults((submittedQuery).toString())
          : AppLocalizations.of(context).sourceRequestIncomplete,
    );
  }

  Widget _buildSearchView(BuildContext context, ContentTab activeTab) {
    final visibleResults = activeTab.sourceId == null
        ? results
        : results.where((app) => app.sourceId == activeTab.sourceId).toList();
    if (!widget.state.hasEnabledSource || visibleResults.isEmpty) {
      return ListView(
        controller: _contentScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          if (!widget.state.hasEnabledSource)
            EmptyMessage(
              icon: Icons.hub_outlined,
              title: AppLocalizations.of(context).noEnabledSources,
              detail: AppLocalizations.of(context).noEnabledSourcesHint,
            )
          else
            _buildSearchEmpty(context, activeTab),
        ],
      );
    }
    final itemCount = visibleResults.length + (loadingMore ? 1 : 0);
    return ListView.builder(
      controller: _contentScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == visibleResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return AppResultTile(
          key: ValueKey(
            '${visibleResults[index].sourceId}:${visibleResults[index].id}',
          ),
          app: visibleResults[index],
          state: widget.state,
          onOpen: (app) => showAppDetails(context, widget.state, app),
          onEnterSelection: _enterSelection,
          onSelect: _toggleSelection,
          selectionMode: _selectionMode,
          selected: _isSelected(visibleResults[index]),
          showDivider: index < visibleResults.length - 1,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showingHome = submittedQuery == null;
      final tabBarWidth =
          constraints.maxWidth -
          (_horizontalContentPadding * 2) -
          _filterButtonExtent;
      final tabs = showingHome
          ? _tabs
          : _visibleSearchTabs(context, tabBarWidth);
      final activeTab = _activeTab(tabs);
      if (!showingHome && activeTab?.id != _selectedTab) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && submittedQuery != null) {
            setState(() => _selectedTab = activeTab?.id ?? 'all');
          }
        });
      }
      return Column(
        children: [
          if (activeTab != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalContentPadding,
              ),
              child: _buildTabBar(context, tabs, activeTab),
            ),
          Expanded(
            child: Column(
              children: [
                if (_selectionMode)
                  AppSelectionToolbar(
                    selectedCount: _selectedApps.length,
                    onClose: _exitSelection,
                    onDownload: _downloadSelected,
                    onFavorite: _favoriteSelected,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshContent,
                    child: showingHome
                        ? _buildCatalogView(context, activeTab)
                        : _buildSearchView(context, activeTab!),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({required this.initialPage});

  final int initialPage;

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final text = widget.initialPage.toString();
    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_controller.text);
    if (page == null || page < 1) {
      setState(() => _errorText = AppLocalizations.of(context).invalidPage);
      return;
    }
    Navigator.pop(context, page);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppLocalizations.of(context).jumpToPage),
    content: TextField(
      key: const ValueKey('page-jump-field'),
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).pageNumber,
        prefixIcon: const Icon(Icons.numbers),
        errorText: _errorText,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context).cancel),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(AppLocalizations.of(context).jump),
      ),
    ],
  );
}

class _SourcePickerResult {
  const _SourcePickerResult.preview(String sourceId)
    : previewSourceId = sourceId,
      selectedSourceIds = null;

  const _SourcePickerResult.apply(List<String> sourceIds)
    : previewSourceId = null,
      selectedSourceIds = sourceIds;

  final String? previewSourceId;
  final List<String>? selectedSourceIds;
}

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({
    required this.sources,
    required this.selectedSourceIds,
  });

  final List<ApkSource> sources;
  final List<String> selectedSourceIds;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  final _query = TextEditingController();
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedSourceIds.toSet();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setSelected(String sourceId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(sourceId);
      } else {
        _selectedIds.remove(sourceId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _query.text.trim().toLowerCase();
    final sources = keyword.isEmpty
        ? widget.sources
        : widget.sources
              .where(
                (source) =>
                    source.name.toLowerCase().contains(keyword) ||
                    source.id.toLowerCase().contains(keyword) ||
                    source.homepage.toLowerCase().contains(keyword),
              )
              .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).searchSourceTabs,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).automaticTabs,
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => setState(_selectedIds.clear),
                  icon: const Icon(Icons.restart_alt),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: AppLocalizations.of(context).sourceSearchHint,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                final selected = _selectedIds.contains(source.id);
                return ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    source.homepage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: AppLocalizations.of(
                          context,
                        ).previewSourceResults,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        onPressed: () => Navigator.pop(
                          context,
                          _SourcePickerResult.preview(source.id),
                        ),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      const SizedBox(width: 2),
                      Checkbox(
                        value: selected,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) =>
                            _setSelected(source.id, value ?? false),
                      ),
                    ],
                  ),
                  onTap: () => _setSelected(source.id, !selected),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _SourcePickerResult.apply([
                    for (final source in widget.sources)
                      if (_selectedIds.contains(source.id)) source.id,
                  ]),
                ),
                icon: const Icon(Icons.check),
                label: Text(AppLocalizations.of(context).apply),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchLoadingView extends StatefulWidget {
  const SearchLoadingView({
    this.icon = Icons.manage_search,
    this.label,
    super.key,
  });

  final IconData icon;
  final String? label;

  @override
  State<SearchLoadingView> createState() => _SearchLoadingViewState();
}

class _SearchLoadingViewState extends State<SearchLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final sweep = -1.8 + (_controller.value * 3.6);
            final highlight = Color.lerp(
              scheme.primary,
              scheme.onPrimary,
              0.5,
            )!;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(sweep, 0),
                end: Alignment(sweep + 1.5, 0),
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, highlight, 0.5)!,
                  highlight,
                  Color.lerp(scheme.primary, highlight, 0.5)!,
                  scheme.primary,
                ],
                stops: const [0, 0.3, 0.5, 0.7, 1],
              ).createShader(bounds),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 88, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                widget.label ?? AppLocalizations.of(context).searching,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchErrorSheet extends StatelessWidget {
  const SearchErrorSheet({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).searchErrorDetails,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).copyError,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).errorCopied),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentTab {
  const ContentTab({
    required this.id,
    required this.label,
    this.catalogTab,
    this.sourceId,
  });

  final String id;
  final String label;
  final SourceCatalogTab? catalogTab;
  final String? sourceId;
}

class _CatalogTabLoadState {
  List<AppListing> apps = const [];
  final Set<String> seenIds = {};
  int currentPage = 1;
  int nextPage = 1;
  bool loaded = false;
  bool loading = false;
  bool hasMore = true;
  String? error;
}
