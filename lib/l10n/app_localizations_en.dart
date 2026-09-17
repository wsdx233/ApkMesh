// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadAction => 'Download';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoriteAction => 'Add to favorites';

  @override
  String get sources => 'Sources';

  @override
  String get settings => 'Settings';

  @override
  String get backHome => 'Back to home';

  @override
  String get searchHint => 'Search by app name or package name';

  @override
  String get translateEnglish => 'Translate to English';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get search => 'Search';

  @override
  String get jumpToPage => 'Jump to page';

  @override
  String get debug => 'Debug';

  @override
  String translationFailed(String error) {
    return 'Translation failed: $error';
  }

  @override
  String get debugInformation => 'Debug information';

  @override
  String debugCounts(String requests, String logs) {
    return 'Requests: $requests · Logs: $logs';
  }

  @override
  String get clearDebug => 'Clear debug records';

  @override
  String get close => 'Close';

  @override
  String get overview => 'Overview';

  @override
  String get requests => 'Requests';

  @override
  String get projects => 'Projects';

  @override
  String get logs => 'Logs';

  @override
  String get runtime => 'Runtime';

  @override
  String get quickJsLoaded => 'QuickJS sources loaded';

  @override
  String get usingDemo => 'Using demo source';

  @override
  String enabledSources(String names) {
    return 'Enabled sources: $names';
  }

  @override
  String get available => 'Available';

  @override
  String get unavailable => 'Unavailable';

  @override
  String runtimeCapabilities(String count, String availability) {
    return 'Active tabs: $count · Installation: $availability';
  }

  @override
  String get webViewStatus => 'WebView status';

  @override
  String get noWebViewTabs => 'No WebView tabs';

  @override
  String get webViewPreviewHint =>
      'Run a debug project, then tap a tab to view its page.';

  @override
  String get recentRequests => 'Recent requests';

  @override
  String itemCount(String count) {
    return 'Count: $count';
  }

  @override
  String get noRequests => 'No requests';

  @override
  String get runtimeLogs => 'Runtime logs';

  @override
  String get noLogs => 'No logs';

  @override
  String get requestRecords => 'Request records';

  @override
  String requestRecordsCount(String count) {
    return 'Count: $count · Tap to view content';
  }

  @override
  String get noRequestRecords => 'No request records';

  @override
  String get requestRecordsHint =>
      'Requests appear here after an app search or a search debug project.';

  @override
  String get webViewDetailsHint =>
      'Run the app details project, then open its tab to view the page.';

  @override
  String get debugProjects => 'Debug projects';

  @override
  String get noDebugProjects => 'The source declares no debug projects';

  @override
  String get debugProjectsHint =>
      'Sources can declare debug workflows in manifest.debugProjects.';

  @override
  String logCount(String count) {
    return 'Entries: $count';
  }

  @override
  String get logsHint =>
      'Events appear here after searches, details requests, or debug projects.';

  @override
  String enterValue(String label) {
    return 'Please enter $label';
  }

  @override
  String debugProjectFailed(String error) {
    return 'Debug project failed: $error';
  }

  @override
  String get runDebugProject => 'Run debug project';

  @override
  String get inProgress => 'In progress';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String requestSummary(String url, String milliseconds, String characters) {
    return '$url\n$milliseconds ms · Characters: $characters';
  }

  @override
  String get responseBody => 'Response body';

  @override
  String get requestDetails => 'Request details';

  @override
  String get noResponseBody => 'No response body';

  @override
  String get requestHeaders => 'Request headers';

  @override
  String get responseHeaders => 'Response headers';

  @override
  String get status => 'Status';

  @override
  String get loading => 'Loading';

  @override
  String get webViewPreview => 'WebView preview';

  @override
  String get active => 'Active';

  @override
  String get history => 'History';

  @override
  String get loadingProgress => 'Loading';

  @override
  String get loaded => 'Loaded';

  @override
  String get loadFailed => 'Loading failed';

  @override
  String get webViewUnsupported =>
      'Visual WebView is unavailable on this platform. Only tabs and activity records are retained.';

  @override
  String get closed => 'Closed';

  @override
  String get none => 'None';

  @override
  String get noAppWebpage => 'This app has no webpage to open';

  @override
  String sourcePolicyReadFailed(String error) {
    return 'Unable to read source permissions: $error';
  }

  @override
  String get webpageNotAllowed =>
      'This source does not allow opening this webpage';

  @override
  String get noBrowser => 'No browser is available on this system';

  @override
  String browserOpenFailed(String error) {
    return 'Unable to open browser: $error';
  }

  @override
  String get noSearchableName => 'This app has no name to search for';

  @override
  String get loadingDetails => 'Loading details';

  @override
  String sourceDetailsFailed(String error) {
    return 'Unable to load source details: $error';
  }

  @override
  String downloadLinksFailed(String error) {
    return 'Unable to resolve download links: $error';
  }

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get refreshDetails => 'Refresh details';

  @override
  String get openBrowser => 'Open in browser';

  @override
  String get showOriginal => 'Show original';

  @override
  String get translateNameDescription => 'Translate name and description';

  @override
  String get switchSource => 'Switch source';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get downloadFiles => 'Download files';

  @override
  String get findingDownloads => 'Looking for downloads…';

  @override
  String get comments => 'Comments';

  @override
  String get sourceSearchFailed => 'Source search failed';

  @override
  String partialSourceSearchFailed(String names) {
    return 'Some sources failed to search: $names';
  }

  @override
  String get searching => 'Searching';

  @override
  String get sameNameSearchFailed => 'Unable to search for matching apps';

  @override
  String get noSameNameApps => 'No apps with exactly the same name';

  @override
  String get firstPageOnly =>
      'Only first-page results from enabled sources are shown.';

  @override
  String get noDownloadLinks => 'No usable download links found';

  @override
  String get expandDescription => '... Tap to expand';

  @override
  String get downloadStarted =>
      'Download started. Check progress in Downloads.';

  @override
  String get sentToBrowser => 'Sent to browser';

  @override
  String get sentToDownloader => 'Sent to external downloader';

  @override
  String cannotStartDownload(String error) {
    return 'Unable to start download: $error';
  }

  @override
  String get noDownloads => 'No downloads';

  @override
  String get noDownloadsHint =>
      'Select a file in app details to start a download here.';

  @override
  String selectedDownloads(String count) {
    return 'Selected downloads: $count';
  }

  @override
  String get downloadManager => 'Download manager';

  @override
  String get exitSelection => 'Exit selection';

  @override
  String get cleanDownloads => 'Clean up downloads';

  @override
  String get clearAll => 'Clear all';

  @override
  String get clearCompleted => 'Clear completed';

  @override
  String get selectAll => 'Select all';

  @override
  String get invertSelection => 'Invert selection';

  @override
  String get selectRange => 'Select range';

  @override
  String get pauseSelectedDownloads => 'Pause selected downloads';

  @override
  String get resumeSelectedDownloads => 'Resume selected downloads';

  @override
  String get cancelSelectedDownloads => 'Cancel selected downloads';

  @override
  String get retrySelectedDownloads => 'Retry selected downloads';

  @override
  String get deleteSelectedDownloads => 'Delete selected downloads';

  @override
  String get bulkActions => 'Bulk actions';

  @override
  String get selectRangeHint => 'Select the start and end of the range first';

  @override
  String get cancelSelectedTitle => 'Cancel selected downloads?';

  @override
  String cancelSelectedMessage(String count) {
    return 'Active downloads to cancel and remove: $count.';
  }

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get deleteSelectedTitle => 'Delete selected downloads?';

  @override
  String deleteSelectedMessage(String count) {
    return 'Download files and records to delete: $count.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearCompletedTitle => 'Clear completed downloads?';

  @override
  String get clearAllDownloadsTitle => 'Clear all downloads?';

  @override
  String clearCompletedMessage(String count) {
    return 'Completed files and records to delete: $count.';
  }

  @override
  String clearAllDownloadsMessage(String count) {
    return 'Download files and records to delete: $count. Active downloads will also be canceled.';
  }

  @override
  String get clear => 'Clear';

  @override
  String get deleteDownloadTitle => 'Delete download?';

  @override
  String deleteDownloadMessage(String name) {
    return 'Delete “$name” and its download record.';
  }

  @override
  String get openFailed => 'Unable to open';

  @override
  String get deleteDownload => 'Delete download';

  @override
  String get openDetails => 'Open details';

  @override
  String get resumeDownload => 'Resume download';

  @override
  String get pauseDownload => 'Pause download';

  @override
  String get open => 'Open';

  @override
  String get install => 'Install';

  @override
  String get retryDownload => 'Retry download';

  @override
  String downloadedBytes(String size) {
    return 'Downloaded $size';
  }

  @override
  String get connecting => 'Connecting';

  @override
  String downloadSpeed(String size) {
    return 'Speed $size/s';
  }

  @override
  String remainingTime(String duration) {
    return 'About $duration remaining';
  }

  @override
  String get transferNotStarted => 'Transfer not started';

  @override
  String pausedProgress(String progress) {
    return 'Paused · $progress';
  }

  @override
  String downloadFailedDetail(String error) {
    return 'Download failed\n$error';
  }

  @override
  String get unknownError => 'Unknown error';

  @override
  String get canceled => 'Canceled';

  @override
  String hoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String hours(String hours) {
    return '$hours h';
  }

  @override
  String minutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String minutes(String minutes) {
    return '$minutes min';
  }

  @override
  String seconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get installedWithShizuku => 'Installed using Shizuku';

  @override
  String get sentToInstaller => 'Sent to system installer';

  @override
  String get installationIncomplete =>
      'Installation not completed. Check installation permission and retry.';

  @override
  String get installationFailed => 'Installation failed';

  @override
  String get details => 'Details';

  @override
  String errorDetails(String summary) {
    return '$summary details';
  }

  @override
  String get alreadyFavorites => 'Selected apps are already in favorites';

  @override
  String appsFavorited(String count) {
    return 'Apps added to favorites: $count';
  }

  @override
  String get resolvingDownloadsBackground =>
      'Resolving download links in the background…';

  @override
  String get batchDownloadNoLinks =>
      'Batch download failed: no usable download links';

  @override
  String filesStarted(String count) {
    return 'Files started: $count. Check progress in Downloads.';
  }

  @override
  String filesStartedWithErrors(String count, String failed) {
    return 'Files started: $count. Apps with link or download errors: $failed.';
  }

  @override
  String batchDownloadFailed(String error) {
    return 'Batch download failed: $error';
  }

  @override
  String get searchSourcesFailed => 'Unable to load search sources';

  @override
  String get allSources => 'All sources';

  @override
  String get filterSearchSources => 'Filter search sources';

  @override
  String get noEnabledSources => 'No enabled sources';

  @override
  String get noEnabledSourcesHint => 'Enable a source in Sources first.';

  @override
  String get loadingHome => 'Loading home';

  @override
  String get homeLoadFailed => 'Unable to load home content';

  @override
  String get retry => 'Retry';

  @override
  String get noCatalog => 'No catalog content';

  @override
  String get noCatalogHint => 'The home source returned no usable tabs.';

  @override
  String loadingNamed(String name) {
    return 'Loading $name';
  }

  @override
  String namedLoadFailed(String name) {
    return 'Unable to load $name';
  }

  @override
  String get noApps => 'No apps';

  @override
  String get noAppsHint => 'This tab returned no usable apps.';

  @override
  String get nextPageFailed => 'Unable to load the next page';

  @override
  String get noResults => 'No results';

  @override
  String searchedAllSources(String query) {
    return 'Searched all enabled sources for “$query”.';
  }

  @override
  String noSourceResults(String query) {
    return 'This source returned no results for “$query”.';
  }

  @override
  String get sourceRequestIncomplete =>
      'The source request did not finish. Open error details for the cause.';

  @override
  String get invalidPage => 'Enter a page number greater than 0';

  @override
  String get pageNumber => 'Page number';

  @override
  String get jump => 'Go';

  @override
  String get searchSourceTabs => 'Search source tabs';

  @override
  String get automaticTabs => 'Restore automatic tabs';

  @override
  String get sourceSearchHint => 'Search source name or domain';

  @override
  String get previewSourceResults => 'Preview results from this source';

  @override
  String get apply => 'Apply';

  @override
  String get searchErrorDetails => 'Search error details';

  @override
  String get copyError => 'Copy error details';

  @override
  String get errorCopied => 'Error details copied';

  @override
  String get noHistory => 'No history';

  @override
  String get noFavorites => 'No favorites';

  @override
  String get noHistoryHint =>
      'Apps appear here automatically when you open their details.';

  @override
  String get noFavoritesHint =>
      'Tap the bookmark in an app list or details to add a favorite.';

  @override
  String get browsingHistory => 'Browsing history';

  @override
  String get myFavorites => 'My favorites';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearFavorites => 'Clear favorites';

  @override
  String get clearHistoryTitle => 'Clear browsing history?';

  @override
  String get clearFavoritesTitle => 'Clear favorites?';

  @override
  String get clearHistoryMessage => 'This removes all browsing history.';

  @override
  String get clearFavoritesMessage => 'This removes all favorite apps.';

  @override
  String get clearLibrary => 'Clear';

  @override
  String get followSystem => 'Follow system';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get internalDownload => 'In-app';

  @override
  String get browser => 'Browser';

  @override
  String get externalDownloader => 'External downloader';

  @override
  String get theme => 'Theme';

  @override
  String get downloadDirectory => 'Download directory';

  @override
  String get downloadDirectorySummary =>
      'In-app downloads use the system download directory';

  @override
  String get downloadDirectoryInternal =>
      'In-app downloads are saved to the platform download directory, or the app documents directory if no download directory is available.';

  @override
  String get downloadDirectoryExternal =>
      'When using a browser or external downloader, that app controls the save location.';

  @override
  String get installPermission => 'Installation permission';

  @override
  String get installPermissionSummary =>
      'Allow this app to install unknown apps before installing APKs';

  @override
  String get installUnsupported =>
      'APK installation is unavailable on this platform';

  @override
  String get installPermissionDetails =>
      'APK installation is only available on Android. User-initiated installation does not require the source to declare installation permission; source-initiated installation still does.';

  @override
  String get legalSafety => 'Legal and safety';

  @override
  String get legalSafetySummary =>
      'Confirm authorization and trust before using third-party sources and APKs';

  @override
  String get legalAuthorization =>
      'Only import sources you are authorized to access and use. Follow each site\'s terms of service and local laws.';

  @override
  String get legalVerification =>
      'APK Mesh does not verify third-party downloads. Check the source, package name, version, and signature before installation, and scan files using trusted security tools.';

  @override
  String get legalPermissions =>
      'Declared network, browser, download, and installation permissions limit source scripts, but do not prevent users from manually installing downloaded APKs.';

  @override
  String get githubProject => 'GitHub project';

  @override
  String get githubSummary => 'View source code, issues, and releases';

  @override
  String get aboutApp => 'About APK Mesh';

  @override
  String get aboutSummary => 'Open-source APK source aggregator · 1.0.0';

  @override
  String get aboutDescription =>
      'APK Mesh is an open-source APK source aggregator. Independent source scripts, constrained by permission policies, search for apps, parse details, and retrieve download URLs.';

  @override
  String get appVersion => 'Version 1.0.0';

  @override
  String get githubOpenFailed => 'Unable to open the GitHub project';

  @override
  String get downloadMethod => 'Download method';

  @override
  String get internalDownloadHint =>
      'Download in APK Mesh with progress, pause, resume, and installation controls';

  @override
  String get browserDownloadHint =>
      'Open download links in the default system browser';

  @override
  String get externalDownloaderHint =>
      'Choose an app such as ADM or 1DM that supports download intents';

  @override
  String get externalDownloaderUnsupported =>
      'External downloaders are unavailable on this platform';

  @override
  String get sourceConcurrency => 'Source concurrency';

  @override
  String get httpRequests => 'HTTP requests';

  @override
  String get httpConcurrencyHint =>
      'Maximum simultaneous source network requests';

  @override
  String get headlessWebView => 'Headless WebView';

  @override
  String get webViewConcurrencyHint =>
      'Maximum simultaneously active browser tabs';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get concurrency => 'Concurrency';

  @override
  String get minimumOne => 'At least 1';

  @override
  String get shizukuAuthorizedEnabled =>
      'Authorized. Tapping Install will install APKs using Shizuku.';

  @override
  String get shizukuAuthorizedDisabled =>
      'Authorized. Enable to install APKs using Shizuku.';

  @override
  String get shizukuNotRunningEnabled =>
      'Shizuku is not running. Start it before installing.';

  @override
  String get shizukuNotRunningDisabled =>
      'Start Shizuku before enabling this option.';

  @override
  String get shizukuDenied => 'Shizuku has not granted APK Mesh permission';

  @override
  String get shizukuUnsupported =>
      'Shizuku installation is unavailable on this platform';

  @override
  String shizukuAuthorizationFailed(String error) {
    return 'Shizuku authorization failed: $error';
  }

  @override
  String get useShizuku => 'Install using Shizuku';

  @override
  String get translation => 'Translation';

  @override
  String get translationSettings => 'Translation settings';

  @override
  String get autoTranslate =>
      'Automatically translate app names and descriptions';

  @override
  String get autoTranslateHint =>
      'Request translations after search results and details load';

  @override
  String get translationService => 'Translation service';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get googleApiKey => 'Google public API key (optional)';

  @override
  String get googleApiKeyHint =>
      'Leave empty to use the legacy Google Translate browser API.';

  @override
  String get translationPrivacy =>
      'Text is sent to the selected provider or its gateway. Original text is retained if the service is unavailable or the request fails.';

  @override
  String get waitingForTest => 'Waiting for test';

  @override
  String testInputHint(String label) {
    return 'Enter $label to start testing';
  }

  @override
  String get testing => 'Testing';

  @override
  String get testLiveHint => 'Testing in progress; status updates in real time';

  @override
  String get testSucceeded => 'Test succeeded';

  @override
  String get testCompleted => 'Test completed';

  @override
  String get testFailed => 'Test failed';

  @override
  String get testIncomplete => 'Test not completed';

  @override
  String get liveStatus => 'Live status';

  @override
  String requestCount(String count) {
    return 'Requests: $count';
  }

  @override
  String requestStatusCounts(String pending, String completed, String failed) {
    return 'In progress: $pending · Completed: $completed · Failed: $failed';
  }

  @override
  String webViewCount(String count) {
    return 'WebViews: $count';
  }

  @override
  String get recentEvents => 'Recent events';

  @override
  String get testResults => 'Test results';

  @override
  String get retest => 'Retest';

  @override
  String get runTest => 'Run test';

  @override
  String get disableFailedTitle => 'Disable sources that failed testing?';

  @override
  String disableFailedMessage(String count) {
    return 'Sources to disable after failed tests: $count.';
  }

  @override
  String get disableSources => 'Disable sources';

  @override
  String get batchTestSources => 'Batch test sources';

  @override
  String batchTestQuery(String query, String count) {
    return 'Search “$query” · Sources: $count';
  }

  @override
  String batchTestProgress(
    String completed,
    String total,
    String available,
    String failed,
  ) {
    return 'Testing · Completed: $completed/$total · Available: $available · Failed: $failed';
  }

  @override
  String batchTestCounts(String available, String failed) {
    return 'Available: $available · Failed: $failed';
  }

  @override
  String disableFailedSources(String count) {
    return 'Disable failed ($count)';
  }

  @override
  String get batchTestIncomplete => 'Batch test did not finish';

  @override
  String get notTested => 'Not tested';

  @override
  String sourceTestAvailable(String count) {
    return 'Available · Search results: $count';
  }

  @override
  String sourceTestUnavailable(String error) {
    return 'Unavailable · $error';
  }

  @override
  String get sourceCurrentlyDisabled => ' · Currently disabled';

  @override
  String get batchTest => 'Batch test';

  @override
  String get importSource => 'Import source';

  @override
  String selectedSources(String count) {
    return 'Selected sources: $count';
  }

  @override
  String get enableSelectedSources => 'Enable selected sources';

  @override
  String get disableSelectedSources => 'Disable selected sources';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String sourcesImported(String count) {
    return 'Sources imported: $count';
  }

  @override
  String sourcesImportedWithErrors(String count, String failed) {
    return 'Sources imported: $count · Failed: $failed';
  }

  @override
  String get sourceUrl => 'Source URL';

  @override
  String get importSourceFile => 'Choose a JS or ZIP file';

  @override
  String get enterSourceUrl => 'Enter a source URL';

  @override
  String get importSourceUrl => 'Import from URL';

  @override
  String get viewTestProjects => 'View test projects';

  @override
  String get noTestProjects => 'No test projects';

  @override
  String get test => 'Test';

  @override
  String get deleteSource => 'Delete source';

  @override
  String get backgroundDownloadHint =>
      'Resolve links in the background and add downloads';

  @override
  String get multiSelect => 'Select multiple';

  @override
  String get multiSelectHint => 'Select apps to download or favorite in bulk';

  @override
  String get resolvingDownload => 'Resolving download links…';

  @override
  String filesStartedPartial(String count) {
    return 'Files started: $count, but some links could not be processed';
  }

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String selectedApps(String count) {
    return 'Selected apps: $count';
  }

  @override
  String get favoriteSelectedApps => 'Favorite selected apps';

  @override
  String get downloadSelectedApps => 'Download selected apps';

  @override
  String get lookupPackage => 'Find apps by package name';

  @override
  String get lookupPackageTitle => 'Find by package name';

  @override
  String get packageLookupFailed => 'Package lookup failed';

  @override
  String get noMatchingApps => 'No matching apps';

  @override
  String get noPackageSources => 'No sources available for package lookup';

  @override
  String get packageSearchedHint =>
      'Searched enabled package-lookup sources for this package.';

  @override
  String get enablePackageSourceHint =>
      'Enable a source that declares package-lookup support first.';

  @override
  String get saveImage => 'Save image';

  @override
  String imageRequestFailed(String status) {
    return 'Image request failed: HTTP $status';
  }

  @override
  String get imageSaved => 'Image saved to gallery';

  @override
  String imageSaveFailed(String error) {
    return 'Unable to save image: $error';
  }

  @override
  String get demoSourceDescription =>
      'Built-in demo source for testing APKVision search, details, and downloads.';

  @override
  String get translationClosed => 'The translation service has been closed';

  @override
  String get translationEmpty => 'The translation API returned no results';

  @override
  String providerTranslationFailed(String provider, String error) {
    return '$provider translation failed: $error';
  }

  @override
  String shizukuStatusFailed(String error) {
    return 'Unable to read Shizuku status: $error';
  }

  @override
  String installStatusFailed(String name, String error) {
    return 'Unable to read installation status: $name · $error';
  }

  @override
  String get appNotInstalled =>
      'This APK version is not installed or cannot be opened';

  @override
  String get installedAppOpenFailed => 'Unable to open the installed app';

  @override
  String settingsRestoreFailed(String error) {
    return 'Unable to restore settings: $error';
  }

  @override
  String get builtInQuickJsSource => 'Built-in QuickJS source';

  @override
  String downloadsRestored(String count) {
    return 'Downloads restored: $count';
  }

  @override
  String downloadsRestoreFailed(String error) {
    return 'Unable to restore downloads: $error';
  }

  @override
  String downloadsSaveFailed(String error) {
    return '[APK Mesh] Unable to save downloads: $error';
  }

  @override
  String get downloadSourceMissing =>
      'Download source unavailable. Import it again and retry.';

  @override
  String get scanningSources => 'Scanning built-in QuickJS sources';

  @override
  String bundledSourcesFound(String count) {
    return 'Built-in source scripts found: $count';
  }

  @override
  String sourceLoaded(String path) {
    return 'Source loaded: $path';
  }

  @override
  String sourceLoadFailed(String path, String error) {
    return 'QuickJS source failed to load ($path): $error';
  }

  @override
  String get sourceReadFailed => 'Unable to read the JS source script';

  @override
  String get sourceImportUnsupported =>
      'QuickJS source import is unavailable on this platform';

  @override
  String get sourceMissingId => 'Source manifest has no valid ID';

  @override
  String sourceIdExists(String id) {
    return 'Source ID already exists: $id';
  }

  @override
  String get sourceHttpsRequired => 'Source URL must use HTTPS';

  @override
  String get sourceRuntimeMissing => 'Source runtime not loaded';

  @override
  String batchTestStarted(String query) {
    return 'Starting batch source tests: search “$query”';
  }

  @override
  String batchTestFinished(String available, String failed) {
    return 'Batch tests finished: Available: $available · Failed: $failed';
  }

  @override
  String searchStarted(String query) {
    return 'Starting aggregated search: $query';
  }

  @override
  String sourceExecutionFailed(String source, String error) {
    return '$source failed: $error';
  }

  @override
  String searchFinished(String count) {
    return 'Aggregated search finished · Results: $count';
  }

  @override
  String packageLookupStarted(String package) {
    return 'Starting package lookup: $package';
  }

  @override
  String packageLookupFinished(String count) {
    return 'Package lookup finished · Results: $count';
  }

  @override
  String searchPageStarted(String page, String query) {
    return 'Loading search page $page: $query';
  }

  @override
  String searchPageFinished(String page, String count) {
    return 'Search page $page finished · Results: $count';
  }

  @override
  String get noAppDetails => 'No app details returned';

  @override
  String candidateNoLinks(String name) {
    return '$name: No usable download links found';
  }

  @override
  String get wrongHomeSource =>
      'This catalog tab does not belong to the current home source';

  @override
  String sourceDisabled(String id) {
    return 'Source is not enabled: $id';
  }

  @override
  String debugProjectStarted(String name, String input) {
    return 'Starting debug project: $name · $input';
  }

  @override
  String debugProjectError(String name, String error) {
    return 'Debug project failed: $name · $error';
  }

  @override
  String notificationInstallFailed(String name, String error) {
    return 'Installation from notification failed: $name · $error';
  }

  @override
  String get appStateClosed => 'App state has been closed';

  @override
  String get downloadPermissionMissing =>
      'This source has not declared download permission';

  @override
  String get downloadUrlDenied =>
      'Source permissions deny access to the download URL';

  @override
  String get noExternalDownloader => 'No external downloader available';

  @override
  String externalDownloadReceived(String method, String name) {
    return '$method received: $name';
  }

  @override
  String downloadStarting(String name) {
    return 'Starting download: $name';
  }

  @override
  String downloadPausing(String name) {
    return 'Pausing download: $name';
  }

  @override
  String downloadPauseFailed(String name, String error) {
    return 'Unable to pause download: $name · $error';
  }

  @override
  String downloadResuming(String name) {
    return 'Resuming download: $name';
  }

  @override
  String downloadResumeFailed(String name, String error) {
    return 'Unable to resume download: $name · $error';
  }

  @override
  String downloadCanceling(String name) {
    return 'Canceling download: $name';
  }

  @override
  String downloadCancelCleanupFailed(String name, String error) {
    return 'Unable to clean up canceled download: $name · $error';
  }

  @override
  String downloadDeleteFailed(String name, String error) {
    return 'Unable to delete download file: $name · $error';
  }

  @override
  String downloadDeleting(String name) {
    return 'Deleting download: $name';
  }

  @override
  String downloadSessionCleanupFailed(String name, String error) {
    return 'Unable to clean up download session: $name · $error';
  }

  @override
  String downloadCompleted(String name) {
    return 'Download completed: $name';
  }

  @override
  String downloadCanceled(String name) {
    return 'Download canceled: $name';
  }

  @override
  String downloadError(String name, String error) {
    return 'Download failed: $name · $error';
  }

  @override
  String get downloadNotComplete => 'The download has not finished';

  @override
  String get installationInProgress =>
      'This installation is already in progress';

  @override
  String get microsoftTranslator => 'Microsoft Edge/Bing';

  @override
  String get freeTranslator => 'Free translation service';

  @override
  String get translationCountMismatch =>
      'The number of translations does not match the request';

  @override
  String get microsoftResponseInvalid =>
      'Invalid Microsoft translation response';

  @override
  String get freeTranslationResponseInvalid =>
      'Invalid free translation service response';

  @override
  String get freeTranslationToken => 'Free translation service token';

  @override
  String get translationTokenMissing =>
      'The free translation service returned no token';

  @override
  String translationJsonInvalid(String error) {
    return 'The translation response is not valid JSON: $error';
  }

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get traditionalChinese => 'Traditional Chinese';

  @override
  String get englishLanguage => 'English';

  @override
  String get japaneseLanguage => 'Japanese';

  @override
  String get koreanLanguage => 'Korean';

  @override
  String get spanishLanguage => 'Spanish';

  @override
  String get frenchLanguage => 'French';

  @override
  String get germanLanguage => 'German';

  @override
  String get portugueseLanguage => 'Portuguese';

  @override
  String get appLanguage => 'App language';

  @override
  String get appLanguageHint =>
      'Changes the interface only, not the translation language for source content';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';
}
