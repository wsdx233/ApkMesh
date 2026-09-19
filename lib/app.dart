import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_language.dart';
import 'core/app_state.dart';
import 'core/app_update.dart';
import 'core/models.dart';
import 'l10n/app_localizations.dart';
import 'pages/debug_sheet.dart';
import 'pages/details_sheet.dart';
import 'pages/downloads_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'pages/sources_page.dart';
import 'widgets/update_dialog.dart';

class ApkMeshApp extends StatefulWidget {
  const ApkMeshApp({super.key});

  @override
  State<ApkMeshApp> createState() => _ApkMeshAppState();
}

class _ApkMeshAppState extends State<ApkMeshApp> with WidgetsBindingObserver {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(state.refreshInstallStates());
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    state.updateSystemLocale();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final lightScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff315f8c),
        brightness: Brightness.light,
      );
      final darkScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff315f8c),
        brightness: Brightness.dark,
      );
      return MaterialApp(
        title: 'APK Mesh',
        locale: state.appLanguage.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: (locale, _) => resolveAppLocale(locale),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightScheme,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkScheme,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        themeMode: switch (state.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        home: Shell(state: state),
      );
    },
  );
}

class Shell extends StatefulWidget {
  const Shell({required this.state, super.key});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  bool searchOpen = false;
  String? submittedSearchQuery;
  bool searchLoading = false;
  bool searchTranslationLoading = false;
  bool pageJumpAvailable = false;
  final searchController = TextEditingController();
  final homeKey = GlobalKey<HomePageState>();
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleUpdateCheck();
    });
  }

  void _scheduleUpdateCheck() {
    _updateCheckTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _checkUpdateOnLaunch();
    });
  }

  Future<void> _checkUpdateOnLaunch() async {
    try {
      final release = await widget.state.checkForUpdates(manual: false);
      if (!mounted || release == null) return;
      if (release.hasUpdate(AppVersion.current)) {
        await showUpdateDialog(
          context,
          state: widget.state,
          release: release,
          isManual: false,
        );
      }
    } catch (_) {
      // Auto update check on launch fails silently
    }
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        key: homeKey,
        state: widget.state,
        controller: searchController,
        onSearchLoadingChanged: _handleSearchLoadingChanged,
        onPageJumpAvailabilityChanged: _handlePageJumpAvailabilityChanged,
      ),
      DownloadsPage(
        state: widget.state,
        onOpenDetails: (context, app) =>
            showAppDetails(context, widget.state, app),
      ),
      LibraryPage(state: widget.state),
      SourcesPage(state: widget.state),
      SettingsPage(state: widget.state),
    ];
    final destinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: AppLocalizations.of(context).home,
      ),
      NavigationDestination(
        icon: Icon(Icons.download_outlined),
        selectedIcon: Icon(Icons.download),
        label: AppLocalizations.of(context).downloads,
      ),
      NavigationDestination(
        icon: Icon(Icons.bookmark_border),
        selectedIcon: Icon(Icons.bookmark),
        label: AppLocalizations.of(context).favorites,
      ),
      NavigationDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: AppLocalizations.of(context).sources,
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: AppLocalizations.of(context).settings,
      ),
    ];
    final visibleSearchQuery = index == 0 ? submittedSearchQuery : null;
    final interceptSearchBack = visibleSearchQuery != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final scaffold = Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: index == 0 && searchLoading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            leading: visibleSearchQuery != null
                ? IconButton(
                    tooltip: AppLocalizations.of(context).backHome,
                    onPressed: _returnHome,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              ),
              child: searchOpen
                  ? SizedBox(
                      key: const ValueKey('search-field'),
                      width: double.infinity,
                      height: 46,
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submitSearch(),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).searchHint,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              searchTranslationLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: AppLocalizations.of(
                                        context,
                                      ).translateEnglish,
                                      onPressed: _translateSearch,
                                      icon: const Icon(
                                        Icons.translate_outlined,
                                        size: 20,
                                      ),
                                    ),
                              IconButton(
                                tooltip: AppLocalizations.of(
                                  context,
                                ).clearSearch,
                                onPressed: searchController.clear,
                                icon: const Icon(Icons.clear, size: 20),
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    )
                  : Text(
                      visibleSearchQuery ?? 'APK Mesh',
                      key: ValueKey(
                        visibleSearchQuery == null
                            ? 'app-title'
                            : 'search-title',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            actions: [
              if (index == 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: searchOpen
                      ? IconButton(
                          key: const ValueKey('close-search'),
                          tooltip: AppLocalizations.of(context).closeSearch,
                          onPressed: () => setState(() => searchOpen = false),
                          icon: const Icon(Icons.close),
                        )
                      : IconButton(
                          key: const ValueKey('open-search'),
                          tooltip: AppLocalizations.of(context).search,
                          onPressed: _openSearch,
                          icon: const Icon(Icons.search),
                        ),
                ),
              if (index == 0 && !searchOpen && pageJumpAvailable)
                IconButton(
                  key: const ValueKey('jump-to-page'),
                  tooltip: AppLocalizations.of(context).jumpToPage,
                  onPressed: () => homeKey.currentState?.showPageJumpDialog(),
                  icon: const Icon(Icons.find_in_page_outlined),
                ),
              if (kDebugMode)
                IconButton(
                  tooltip: AppLocalizations.of(context).debug,
                  onPressed: () => _showDebugSheet(context),
                  icon: const Icon(Icons.bug_report_outlined),
                ),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text(AppLocalizations.of(context).home),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download_outlined),
                      selectedIcon: Icon(Icons.download),
                      label: Text(AppLocalizations.of(context).downloads),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bookmark_border),
                      selectedIcon: Icon(Icons.bookmark),
                      label: Text(AppLocalizations.of(context).favorites),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.hub_outlined),
                      selectedIcon: Icon(Icons.hub),
                      label: Text(AppLocalizations.of(context).sources),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text(AppLocalizations.of(context).settings),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: index, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: _selectPage,
                  destinations: destinations,
                  labelTextStyle: constraints.maxWidth < 360
                      ? WidgetStatePropertyAll(
                          Theme.of(context).textTheme.labelSmall,
                        )
                      : null,
                ),
        );
        return PopScope<Object?>(
          canPop: !interceptSearchBack,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && interceptSearchBack) _returnHome();
          },
          child: scaffold,
        );
      },
    );
  }

  void _selectPage(int value) {
    setState(() {
      index = value;
      if (value != 0) searchOpen = false;
    });
  }

  void _openSearch() {
    setState(() {
      index = 0;
      searchOpen = true;
    });
  }

  void _handleSearchLoadingChanged(bool loading) {
    if (!mounted || searchLoading == loading) return;
    setState(() => searchLoading = loading);
  }

  void _handlePageJumpAvailabilityChanged(bool available) {
    if (!mounted || pageJumpAvailable == available) return;
    setState(() => pageJumpAvailable = available);
  }

  Future<void> _translateSearch() async {
    final query = searchController.text.trim();
    if (query.isEmpty || searchTranslationLoading) return;
    setState(() => searchTranslationLoading = true);
    try {
      final translated = await widget.state.translateToEnglish(query);
      if (mounted && searchController.text.trim() == query) {
        searchController.value = TextEditingValue(
          text: translated,
          selection: TextSelection.collapsed(offset: translated.length),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).translationFailed((error).toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => searchTranslationLoading = false);
    }
  }

  Future<void> _submitSearch() async {
    final query = searchController.text.trim();
    setState(() {
      index = 0;
      searchOpen = false;
      submittedSearchQuery = query.isEmpty ? null : query;
    });
    await homeKey.currentState?.search();
  }

  void _returnHome() {
    setState(() {
      index = 0;
      searchOpen = false;
      submittedSearchQuery = null;
    });
    searchController.clear();
    homeKey.currentState?.showHome();
  }

  void _showDebugSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DebugSheet(state: widget.state),
    );
  }
}
