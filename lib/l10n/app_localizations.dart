import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadAction;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @favoriteAction.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAction;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backHome;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by app name or package name'**
  String get searchHint;

  /// No description provided for @translateEnglish.
  ///
  /// In en, this message translates to:
  /// **'Translate to English'**
  String get translateEnglish;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @jumpToPage.
  ///
  /// In en, this message translates to:
  /// **'Jump to page'**
  String get jumpToPage;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String translationFailed(String error);

  /// No description provided for @debugInformation.
  ///
  /// In en, this message translates to:
  /// **'Debug information'**
  String get debugInformation;

  /// No description provided for @debugCounts.
  ///
  /// In en, this message translates to:
  /// **'Requests: {requests} · Logs: {logs}'**
  String debugCounts(String requests, String logs);

  /// No description provided for @clearDebug.
  ///
  /// In en, this message translates to:
  /// **'Clear debug records'**
  String get clearDebug;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get runtime;

  /// No description provided for @quickJsLoaded.
  ///
  /// In en, this message translates to:
  /// **'QuickJS sources loaded'**
  String get quickJsLoaded;

  /// No description provided for @usingDemo.
  ///
  /// In en, this message translates to:
  /// **'Using demo source'**
  String get usingDemo;

  /// No description provided for @enabledSources.
  ///
  /// In en, this message translates to:
  /// **'Enabled sources: {names}'**
  String enabledSources(String names);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @runtimeCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Active tabs: {count} · Installation: {availability}'**
  String runtimeCapabilities(String count, String availability);

  /// No description provided for @webViewStatus.
  ///
  /// In en, this message translates to:
  /// **'WebView status'**
  String get webViewStatus;

  /// No description provided for @noWebViewTabs.
  ///
  /// In en, this message translates to:
  /// **'No WebView tabs'**
  String get noWebViewTabs;

  /// No description provided for @webViewPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Run a debug project, then tap a tab to view its page.'**
  String get webViewPreviewHint;

  /// No description provided for @recentRequests.
  ///
  /// In en, this message translates to:
  /// **'Recent requests'**
  String get recentRequests;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'Count: {count}'**
  String itemCount(String count);

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get noRequests;

  /// No description provided for @runtimeLogs.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs'**
  String get runtimeLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get noLogs;

  /// No description provided for @requestRecords.
  ///
  /// In en, this message translates to:
  /// **'Request records'**
  String get requestRecords;

  /// No description provided for @requestRecordsCount.
  ///
  /// In en, this message translates to:
  /// **'Count: {count} · Tap to view content'**
  String requestRecordsCount(String count);

  /// No description provided for @noRequestRecords.
  ///
  /// In en, this message translates to:
  /// **'No request records'**
  String get noRequestRecords;

  /// No description provided for @requestRecordsHint.
  ///
  /// In en, this message translates to:
  /// **'Requests appear here after an app search or a search debug project.'**
  String get requestRecordsHint;

  /// No description provided for @webViewDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Run the app details project, then open its tab to view the page.'**
  String get webViewDetailsHint;

  /// No description provided for @debugProjects.
  ///
  /// In en, this message translates to:
  /// **'Debug projects'**
  String get debugProjects;

  /// No description provided for @noDebugProjects.
  ///
  /// In en, this message translates to:
  /// **'The source declares no debug projects'**
  String get noDebugProjects;

  /// No description provided for @debugProjectsHint.
  ///
  /// In en, this message translates to:
  /// **'Sources can declare debug workflows in manifest.debugProjects.'**
  String get debugProjectsHint;

  /// No description provided for @logCount.
  ///
  /// In en, this message translates to:
  /// **'Entries: {count}'**
  String logCount(String count);

  /// No description provided for @logsHint.
  ///
  /// In en, this message translates to:
  /// **'Events appear here after searches, details requests, or debug projects.'**
  String get logsHint;

  /// No description provided for @enterValue.
  ///
  /// In en, this message translates to:
  /// **'Please enter {label}'**
  String enterValue(String label);

  /// No description provided for @debugProjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Debug project failed: {error}'**
  String debugProjectFailed(String error);

  /// No description provided for @runDebugProject.
  ///
  /// In en, this message translates to:
  /// **'Run debug project'**
  String get runDebugProject;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @requestSummary.
  ///
  /// In en, this message translates to:
  /// **'{url}\n{milliseconds} ms · Characters: {characters}'**
  String requestSummary(String url, String milliseconds, String characters);

  /// No description provided for @responseBody.
  ///
  /// In en, this message translates to:
  /// **'Response body'**
  String get responseBody;

  /// No description provided for @requestDetails.
  ///
  /// In en, this message translates to:
  /// **'Request details'**
  String get requestDetails;

  /// No description provided for @noResponseBody.
  ///
  /// In en, this message translates to:
  /// **'No response body'**
  String get noResponseBody;

  /// No description provided for @requestHeaders.
  ///
  /// In en, this message translates to:
  /// **'Request headers'**
  String get requestHeaders;

  /// No description provided for @responseHeaders.
  ///
  /// In en, this message translates to:
  /// **'Response headers'**
  String get responseHeaders;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @webViewPreview.
  ///
  /// In en, this message translates to:
  /// **'WebView preview'**
  String get webViewPreview;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @loadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingProgress;

  /// No description provided for @loaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded'**
  String get loaded;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Loading failed'**
  String get loadFailed;

  /// No description provided for @webViewUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Visual WebView is unavailable on this platform. Only tabs and activity records are retained.'**
  String get webViewUnsupported;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @noAppWebpage.
  ///
  /// In en, this message translates to:
  /// **'This app has no webpage to open'**
  String get noAppWebpage;

  /// No description provided for @sourcePolicyReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read source permissions: {error}'**
  String sourcePolicyReadFailed(String error);

  /// No description provided for @webpageNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This source does not allow opening this webpage'**
  String get webpageNotAllowed;

  /// No description provided for @noBrowser.
  ///
  /// In en, this message translates to:
  /// **'No browser is available on this system'**
  String get noBrowser;

  /// No description provided for @browserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open browser: {error}'**
  String browserOpenFailed(String error);

  /// No description provided for @noSearchableName.
  ///
  /// In en, this message translates to:
  /// **'This app has no name to search for'**
  String get noSearchableName;

  /// No description provided for @loadingDetails.
  ///
  /// In en, this message translates to:
  /// **'Loading details'**
  String get loadingDetails;

  /// No description provided for @sourceDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load source details: {error}'**
  String sourceDetailsFailed(String error);

  /// No description provided for @downloadLinksFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to resolve download links: {error}'**
  String downloadLinksFailed(String error);

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unfavorite;

  /// No description provided for @refreshDetails.
  ///
  /// In en, this message translates to:
  /// **'Refresh details'**
  String get refreshDetails;

  /// No description provided for @openBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openBrowser;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @translateNameDescription.
  ///
  /// In en, this message translates to:
  /// **'Translate name and description'**
  String get translateNameDescription;

  /// No description provided for @switchSource.
  ///
  /// In en, this message translates to:
  /// **'Switch source'**
  String get switchSource;

  /// No description provided for @screenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// No description provided for @downloadFiles.
  ///
  /// In en, this message translates to:
  /// **'Download files'**
  String get downloadFiles;

  /// No description provided for @findingDownloads.
  ///
  /// In en, this message translates to:
  /// **'Looking for downloads…'**
  String get findingDownloads;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @sourceSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Source search failed'**
  String get sourceSearchFailed;

  /// No description provided for @partialSourceSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Some sources failed to search: {names}'**
  String partialSourceSearchFailed(String names);

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get searching;

  /// No description provided for @sameNameSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to search for matching apps'**
  String get sameNameSearchFailed;

  /// No description provided for @noSameNameApps.
  ///
  /// In en, this message translates to:
  /// **'No apps with exactly the same name'**
  String get noSameNameApps;

  /// No description provided for @firstPageOnly.
  ///
  /// In en, this message translates to:
  /// **'Only first-page results from enabled sources are shown.'**
  String get firstPageOnly;

  /// No description provided for @noDownloadLinks.
  ///
  /// In en, this message translates to:
  /// **'No usable download links found'**
  String get noDownloadLinks;

  /// No description provided for @expandDescription.
  ///
  /// In en, this message translates to:
  /// **'... Tap to expand'**
  String get expandDescription;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started. Check progress in Downloads.'**
  String get downloadStarted;

  /// No description provided for @sentToBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sent to browser'**
  String get sentToBrowser;

  /// No description provided for @sentToDownloader.
  ///
  /// In en, this message translates to:
  /// **'Sent to external downloader'**
  String get sentToDownloader;

  /// No description provided for @cannotStartDownload.
  ///
  /// In en, this message translates to:
  /// **'Unable to start download: {error}'**
  String cannotStartDownload(String error);

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloads'**
  String get noDownloads;

  /// No description provided for @noDownloadsHint.
  ///
  /// In en, this message translates to:
  /// **'Select a file in app details to start a download here.'**
  String get noDownloadsHint;

  /// No description provided for @selectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Selected downloads: {count}'**
  String selectedDownloads(String count);

  /// No description provided for @downloadManager.
  ///
  /// In en, this message translates to:
  /// **'Download manager'**
  String get downloadManager;

  /// No description provided for @exitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get exitSelection;

  /// No description provided for @cleanDownloads.
  ///
  /// In en, this message translates to:
  /// **'Clean up downloads'**
  String get cleanDownloads;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @clearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompleted;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @invertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert selection'**
  String get invertSelection;

  /// No description provided for @selectRange.
  ///
  /// In en, this message translates to:
  /// **'Select range'**
  String get selectRange;

  /// No description provided for @pauseSelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Pause selected downloads'**
  String get pauseSelectedDownloads;

  /// No description provided for @resumeSelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Resume selected downloads'**
  String get resumeSelectedDownloads;

  /// No description provided for @cancelSelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Cancel selected downloads'**
  String get cancelSelectedDownloads;

  /// No description provided for @retrySelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Retry selected downloads'**
  String get retrySelectedDownloads;

  /// No description provided for @deleteSelectedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Delete selected downloads'**
  String get deleteSelectedDownloads;

  /// No description provided for @bulkActions.
  ///
  /// In en, this message translates to:
  /// **'Bulk actions'**
  String get bulkActions;

  /// No description provided for @selectRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Select the start and end of the range first'**
  String get selectRangeHint;

  /// No description provided for @cancelSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel selected downloads?'**
  String get cancelSelectedTitle;

  /// No description provided for @cancelSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Active downloads to cancel and remove: {count}.'**
  String cancelSelectedMessage(String count);

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @deleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete selected downloads?'**
  String get deleteSelectedTitle;

  /// No description provided for @deleteSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Download files and records to delete: {count}.'**
  String deleteSelectedMessage(String count);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear completed downloads?'**
  String get clearCompletedTitle;

  /// No description provided for @clearAllDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all downloads?'**
  String get clearAllDownloadsTitle;

  /// No description provided for @clearCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Completed files and records to delete: {count}.'**
  String clearCompletedMessage(String count);

  /// No description provided for @clearAllDownloadsMessage.
  ///
  /// In en, this message translates to:
  /// **'Download files and records to delete: {count}. Active downloads will also be canceled.'**
  String clearAllDownloadsMessage(String count);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @deleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get deleteDownloadTitle;

  /// No description provided for @deleteDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}” and its download record.'**
  String deleteDownloadMessage(String name);

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open'**
  String get openFailed;

  /// No description provided for @deleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get deleteDownload;

  /// No description provided for @openDetails.
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get openDetails;

  /// No description provided for @resumeDownload.
  ///
  /// In en, this message translates to:
  /// **'Resume download'**
  String get resumeDownload;

  /// No description provided for @pauseDownload.
  ///
  /// In en, this message translates to:
  /// **'Pause download'**
  String get pauseDownload;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @retryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry download'**
  String get retryDownload;

  /// No description provided for @downloadedBytes.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {size}'**
  String downloadedBytes(String size);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed {size}/s'**
  String downloadSpeed(String size);

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'About {duration} remaining'**
  String remainingTime(String duration);

  /// No description provided for @transferNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Transfer not started'**
  String get transferNotStarted;

  /// No description provided for @pausedProgress.
  ///
  /// In en, this message translates to:
  /// **'Paused · {progress}'**
  String pausedProgress(String progress);

  /// No description provided for @downloadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Download failed\n{error}'**
  String downloadFailedDetail(String error);

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String hoursMinutes(String hours, String minutes);

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String hours(String hours);

  /// No description provided for @minutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String minutesSeconds(String minutes, String seconds);

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutes(String minutes);

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String seconds(String seconds);

  /// No description provided for @installedWithShizuku.
  ///
  /// In en, this message translates to:
  /// **'Installed using Shizuku'**
  String get installedWithShizuku;

  /// No description provided for @sentToInstaller.
  ///
  /// In en, this message translates to:
  /// **'Sent to system installer'**
  String get sentToInstaller;

  /// No description provided for @installationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Installation not completed. Check installation permission and retry.'**
  String get installationIncomplete;

  /// No description provided for @installationFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed'**
  String get installationFailed;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'{summary} details'**
  String errorDetails(String summary);

  /// No description provided for @alreadyFavorites.
  ///
  /// In en, this message translates to:
  /// **'Selected apps are already in favorites'**
  String get alreadyFavorites;

  /// No description provided for @appsFavorited.
  ///
  /// In en, this message translates to:
  /// **'Apps added to favorites: {count}'**
  String appsFavorited(String count);

  /// No description provided for @resolvingDownloadsBackground.
  ///
  /// In en, this message translates to:
  /// **'Resolving download links in the background…'**
  String get resolvingDownloadsBackground;

  /// No description provided for @batchDownloadNoLinks.
  ///
  /// In en, this message translates to:
  /// **'Batch download failed: no usable download links'**
  String get batchDownloadNoLinks;

  /// No description provided for @filesStarted.
  ///
  /// In en, this message translates to:
  /// **'Files started: {count}. Check progress in Downloads.'**
  String filesStarted(String count);

  /// No description provided for @filesStartedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Files started: {count}. Apps with link or download errors: {failed}.'**
  String filesStartedWithErrors(String count, String failed);

  /// No description provided for @batchDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Batch download failed: {error}'**
  String batchDownloadFailed(String error);

  /// No description provided for @searchSourcesFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load search sources'**
  String get searchSourcesFailed;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get allSources;

  /// No description provided for @filterSearchSources.
  ///
  /// In en, this message translates to:
  /// **'Filter search sources'**
  String get filterSearchSources;

  /// No description provided for @noEnabledSources.
  ///
  /// In en, this message translates to:
  /// **'No enabled sources'**
  String get noEnabledSources;

  /// No description provided for @noEnabledSourcesHint.
  ///
  /// In en, this message translates to:
  /// **'Enable a source in Sources first.'**
  String get noEnabledSourcesHint;

  /// No description provided for @loadingHome.
  ///
  /// In en, this message translates to:
  /// **'Loading home'**
  String get loadingHome;

  /// No description provided for @homeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load home content'**
  String get homeLoadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noCatalog.
  ///
  /// In en, this message translates to:
  /// **'No catalog content'**
  String get noCatalog;

  /// No description provided for @noCatalogHint.
  ///
  /// In en, this message translates to:
  /// **'The home source returned no usable tabs.'**
  String get noCatalogHint;

  /// No description provided for @loadingNamed.
  ///
  /// In en, this message translates to:
  /// **'Loading {name}'**
  String loadingNamed(String name);

  /// No description provided for @namedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load {name}'**
  String namedLoadFailed(String name);

  /// No description provided for @noApps.
  ///
  /// In en, this message translates to:
  /// **'No apps'**
  String get noApps;

  /// No description provided for @noAppsHint.
  ///
  /// In en, this message translates to:
  /// **'This tab returned no usable apps.'**
  String get noAppsHint;

  /// No description provided for @nextPageFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the next page'**
  String get nextPageFailed;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @searchedAllSources.
  ///
  /// In en, this message translates to:
  /// **'Searched all enabled sources for “{query}”.'**
  String searchedAllSources(String query);

  /// No description provided for @noSourceResults.
  ///
  /// In en, this message translates to:
  /// **'This source returned no results for “{query}”.'**
  String noSourceResults(String query);

  /// No description provided for @sourceRequestIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The source request did not finish. Open error details for the cause.'**
  String get sourceRequestIncomplete;

  /// No description provided for @invalidPage.
  ///
  /// In en, this message translates to:
  /// **'Enter a page number greater than 0'**
  String get invalidPage;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page number'**
  String get pageNumber;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get jump;

  /// No description provided for @searchSourceTabs.
  ///
  /// In en, this message translates to:
  /// **'Search source tabs'**
  String get searchSourceTabs;

  /// No description provided for @automaticTabs.
  ///
  /// In en, this message translates to:
  /// **'Restore automatic tabs'**
  String get automaticTabs;

  /// No description provided for @sourceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search source name or domain'**
  String get sourceSearchHint;

  /// No description provided for @previewSourceResults.
  ///
  /// In en, this message translates to:
  /// **'Preview results from this source'**
  String get previewSourceResults;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @searchErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Search error details'**
  String get searchErrorDetails;

  /// No description provided for @copyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error details'**
  String get copyError;

  /// No description provided for @errorCopied.
  ///
  /// In en, this message translates to:
  /// **'Error details copied'**
  String get errorCopied;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get noHistory;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites'**
  String get noFavorites;

  /// No description provided for @noHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Apps appear here automatically when you open their details.'**
  String get noHistoryHint;

  /// No description provided for @noFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark in an app list or details to add a favorite.'**
  String get noFavoritesHint;

  /// No description provided for @browsingHistory.
  ///
  /// In en, this message translates to:
  /// **'Browsing history'**
  String get browsingHistory;

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get myFavorites;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearFavorites.
  ///
  /// In en, this message translates to:
  /// **'Clear favorites'**
  String get clearFavorites;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear browsing history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear favorites?'**
  String get clearFavoritesTitle;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes all browsing history.'**
  String get clearHistoryMessage;

  /// No description provided for @clearFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes all favorite apps.'**
  String get clearFavoritesMessage;

  /// No description provided for @clearLibrary.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLibrary;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @internalDownload.
  ///
  /// In en, this message translates to:
  /// **'In-app'**
  String get internalDownload;

  /// No description provided for @browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browser;

  /// No description provided for @externalDownloader.
  ///
  /// In en, this message translates to:
  /// **'External downloader'**
  String get externalDownloader;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @downloadDirectory.
  ///
  /// In en, this message translates to:
  /// **'Download directory'**
  String get downloadDirectory;

  /// No description provided for @downloadDirectorySummary.
  ///
  /// In en, this message translates to:
  /// **'In-app downloads use the system download directory'**
  String get downloadDirectorySummary;

  /// No description provided for @downloadDirectoryInternal.
  ///
  /// In en, this message translates to:
  /// **'In-app downloads are saved to the platform download directory, or the app documents directory if no download directory is available.'**
  String get downloadDirectoryInternal;

  /// No description provided for @downloadDirectoryExternal.
  ///
  /// In en, this message translates to:
  /// **'When using a browser or external downloader, that app controls the save location.'**
  String get downloadDirectoryExternal;

  /// No description provided for @installPermission.
  ///
  /// In en, this message translates to:
  /// **'Installation permission'**
  String get installPermission;

  /// No description provided for @installPermissionSummary.
  ///
  /// In en, this message translates to:
  /// **'Allow this app to install unknown apps before installing APKs'**
  String get installPermissionSummary;

  /// No description provided for @installUnsupported.
  ///
  /// In en, this message translates to:
  /// **'APK installation is unavailable on this platform'**
  String get installUnsupported;

  /// No description provided for @installPermissionDetails.
  ///
  /// In en, this message translates to:
  /// **'APK installation is only available on Android. User-initiated installation does not require the source to declare installation permission; source-initiated installation still does.'**
  String get installPermissionDetails;

  /// No description provided for @legalSafety.
  ///
  /// In en, this message translates to:
  /// **'Legal and safety'**
  String get legalSafety;

  /// No description provided for @legalSafetySummary.
  ///
  /// In en, this message translates to:
  /// **'Confirm authorization and trust before using third-party sources and APKs'**
  String get legalSafetySummary;

  /// No description provided for @legalAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Only import sources you are authorized to access and use. Follow each site\'\'s terms of service and local laws.'**
  String get legalAuthorization;

  /// No description provided for @legalVerification.
  ///
  /// In en, this message translates to:
  /// **'APK Mesh does not verify third-party downloads. Check the source, package name, version, and signature before installation, and scan files using trusted security tools.'**
  String get legalVerification;

  /// No description provided for @legalPermissions.
  ///
  /// In en, this message translates to:
  /// **'Declared network, browser, download, and installation permissions limit source scripts, but do not prevent users from manually installing downloaded APKs.'**
  String get legalPermissions;

  /// No description provided for @githubProject.
  ///
  /// In en, this message translates to:
  /// **'GitHub project'**
  String get githubProject;

  /// No description provided for @githubSummary.
  ///
  /// In en, this message translates to:
  /// **'View source code, issues, and releases'**
  String get githubSummary;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About APK Mesh'**
  String get aboutApp;

  /// No description provided for @aboutSummary.
  ///
  /// In en, this message translates to:
  /// **'Open-source APK source aggregator · 1.0.0'**
  String get aboutSummary;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'APK Mesh is an open-source APK source aggregator. Independent source scripts, constrained by permission policies, search for apps, parse details, and retrieve download URLs.'**
  String get aboutDescription;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get appVersion;

  /// No description provided for @githubOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the GitHub project'**
  String get githubOpenFailed;

  /// No description provided for @downloadMethod.
  ///
  /// In en, this message translates to:
  /// **'Download method'**
  String get downloadMethod;

  /// No description provided for @internalDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Download in APK Mesh with progress, pause, resume, and installation controls'**
  String get internalDownloadHint;

  /// No description provided for @browserDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Open download links in the default system browser'**
  String get browserDownloadHint;

  /// No description provided for @externalDownloaderHint.
  ///
  /// In en, this message translates to:
  /// **'Choose an app such as ADM or 1DM that supports download intents'**
  String get externalDownloaderHint;

  /// No description provided for @externalDownloaderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'External downloaders are unavailable on this platform'**
  String get externalDownloaderUnsupported;

  /// No description provided for @sourceConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Source concurrency'**
  String get sourceConcurrency;

  /// No description provided for @httpRequests.
  ///
  /// In en, this message translates to:
  /// **'HTTP requests'**
  String get httpRequests;

  /// No description provided for @httpConcurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Maximum simultaneous source network requests'**
  String get httpConcurrencyHint;

  /// No description provided for @headlessWebView.
  ///
  /// In en, this message translates to:
  /// **'Headless WebView'**
  String get headlessWebView;

  /// No description provided for @webViewConcurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Maximum simultaneously active browser tabs'**
  String get webViewConcurrencyHint;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// No description provided for @concurrency.
  ///
  /// In en, this message translates to:
  /// **'Concurrency'**
  String get concurrency;

  /// No description provided for @minimumOne.
  ///
  /// In en, this message translates to:
  /// **'At least 1'**
  String get minimumOne;

  /// No description provided for @shizukuAuthorizedEnabled.
  ///
  /// In en, this message translates to:
  /// **'Authorized. Tapping Install will install APKs using Shizuku.'**
  String get shizukuAuthorizedEnabled;

  /// No description provided for @shizukuAuthorizedDisabled.
  ///
  /// In en, this message translates to:
  /// **'Authorized. Enable to install APKs using Shizuku.'**
  String get shizukuAuthorizedDisabled;

  /// No description provided for @shizukuNotRunningEnabled.
  ///
  /// In en, this message translates to:
  /// **'Shizuku is not running. Start it before installing.'**
  String get shizukuNotRunningEnabled;

  /// No description provided for @shizukuNotRunningDisabled.
  ///
  /// In en, this message translates to:
  /// **'Start Shizuku before enabling this option.'**
  String get shizukuNotRunningDisabled;

  /// No description provided for @shizukuDenied.
  ///
  /// In en, this message translates to:
  /// **'Shizuku has not granted APK Mesh permission'**
  String get shizukuDenied;

  /// No description provided for @shizukuUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Shizuku installation is unavailable on this platform'**
  String get shizukuUnsupported;

  /// No description provided for @shizukuAuthorizationFailed.
  ///
  /// In en, this message translates to:
  /// **'Shizuku authorization failed: {error}'**
  String shizukuAuthorizationFailed(String error);

  /// No description provided for @useShizuku.
  ///
  /// In en, this message translates to:
  /// **'Install using Shizuku'**
  String get useShizuku;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @translationSettings.
  ///
  /// In en, this message translates to:
  /// **'Translation settings'**
  String get translationSettings;

  /// No description provided for @autoTranslate.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate app names and descriptions'**
  String get autoTranslate;

  /// No description provided for @autoTranslateHint.
  ///
  /// In en, this message translates to:
  /// **'Request translations after search results and details load'**
  String get autoTranslateHint;

  /// No description provided for @translationService.
  ///
  /// In en, this message translates to:
  /// **'Translation service'**
  String get translationService;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get targetLanguage;

  /// No description provided for @googleApiKey.
  ///
  /// In en, this message translates to:
  /// **'Google public API key (optional)'**
  String get googleApiKey;

  /// No description provided for @googleApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the legacy Google Translate browser API.'**
  String get googleApiKeyHint;

  /// No description provided for @translationPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Text is sent to the selected provider or its gateway. Original text is retained if the service is unavailable or the request fails.'**
  String get translationPrivacy;

  /// No description provided for @waitingForTest.
  ///
  /// In en, this message translates to:
  /// **'Waiting for test'**
  String get waitingForTest;

  /// No description provided for @testInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter {label} to start testing'**
  String testInputHint(String label);

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get testing;

  /// No description provided for @testLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Testing in progress; status updates in real time'**
  String get testLiveHint;

  /// No description provided for @testSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Test succeeded'**
  String get testSucceeded;

  /// No description provided for @testCompleted.
  ///
  /// In en, this message translates to:
  /// **'Test completed'**
  String get testCompleted;

  /// No description provided for @testFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get testFailed;

  /// No description provided for @testIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Test not completed'**
  String get testIncomplete;

  /// No description provided for @liveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live status'**
  String get liveStatus;

  /// No description provided for @requestCount.
  ///
  /// In en, this message translates to:
  /// **'Requests: {count}'**
  String requestCount(String count);

  /// No description provided for @requestStatusCounts.
  ///
  /// In en, this message translates to:
  /// **'In progress: {pending} · Completed: {completed} · Failed: {failed}'**
  String requestStatusCounts(String pending, String completed, String failed);

  /// No description provided for @webViewCount.
  ///
  /// In en, this message translates to:
  /// **'WebViews: {count}'**
  String webViewCount(String count);

  /// No description provided for @recentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get recentEvents;

  /// No description provided for @testResults.
  ///
  /// In en, this message translates to:
  /// **'Test results'**
  String get testResults;

  /// No description provided for @retest.
  ///
  /// In en, this message translates to:
  /// **'Retest'**
  String get retest;

  /// No description provided for @runTest.
  ///
  /// In en, this message translates to:
  /// **'Run test'**
  String get runTest;

  /// No description provided for @disableFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable sources that failed testing?'**
  String get disableFailedTitle;

  /// No description provided for @disableFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sources to disable after failed tests: {count}.'**
  String disableFailedMessage(String count);

  /// No description provided for @disableSources.
  ///
  /// In en, this message translates to:
  /// **'Disable sources'**
  String get disableSources;

  /// No description provided for @batchTestSources.
  ///
  /// In en, this message translates to:
  /// **'Batch test sources'**
  String get batchTestSources;

  /// No description provided for @batchTestQuery.
  ///
  /// In en, this message translates to:
  /// **'Search “{query}” · Sources: {count}'**
  String batchTestQuery(String query, String count);

  /// No description provided for @batchTestProgress.
  ///
  /// In en, this message translates to:
  /// **'Testing · Completed: {completed}/{total} · Available: {available} · Failed: {failed}'**
  String batchTestProgress(
    String completed,
    String total,
    String available,
    String failed,
  );

  /// No description provided for @batchTestCounts.
  ///
  /// In en, this message translates to:
  /// **'Available: {available} · Failed: {failed}'**
  String batchTestCounts(String available, String failed);

  /// No description provided for @disableFailedSources.
  ///
  /// In en, this message translates to:
  /// **'Disable failed ({count})'**
  String disableFailedSources(String count);

  /// No description provided for @batchTestIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Batch test did not finish'**
  String get batchTestIncomplete;

  /// No description provided for @notTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get notTested;

  /// No description provided for @sourceTestAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available · Search results: {count}'**
  String sourceTestAvailable(String count);

  /// No description provided for @sourceTestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable · {error}'**
  String sourceTestUnavailable(String error);

  /// No description provided for @sourceCurrentlyDisabled.
  ///
  /// In en, this message translates to:
  /// **' · Currently disabled'**
  String get sourceCurrentlyDisabled;

  /// No description provided for @batchTest.
  ///
  /// In en, this message translates to:
  /// **'Batch test'**
  String get batchTest;

  /// No description provided for @importSource.
  ///
  /// In en, this message translates to:
  /// **'Import source'**
  String get importSource;

  /// No description provided for @selectedSources.
  ///
  /// In en, this message translates to:
  /// **'Selected sources: {count}'**
  String selectedSources(String count);

  /// No description provided for @enableSelectedSources.
  ///
  /// In en, this message translates to:
  /// **'Enable selected sources'**
  String get enableSelectedSources;

  /// No description provided for @disableSelectedSources.
  ///
  /// In en, this message translates to:
  /// **'Disable selected sources'**
  String get disableSelectedSources;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @sourcesImported.
  ///
  /// In en, this message translates to:
  /// **'Sources imported: {count}'**
  String sourcesImported(String count);

  /// No description provided for @sourcesImportedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Sources imported: {count} · Failed: {failed}'**
  String sourcesImportedWithErrors(String count, String failed);

  /// No description provided for @sourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get sourceUrl;

  /// No description provided for @importSourceFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a JS or ZIP file'**
  String get importSourceFile;

  /// No description provided for @enterSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a source URL'**
  String get enterSourceUrl;

  /// No description provided for @importSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get importSourceUrl;

  /// No description provided for @viewTestProjects.
  ///
  /// In en, this message translates to:
  /// **'View test projects'**
  String get viewTestProjects;

  /// No description provided for @noTestProjects.
  ///
  /// In en, this message translates to:
  /// **'No test projects'**
  String get noTestProjects;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @deleteSource.
  ///
  /// In en, this message translates to:
  /// **'Delete source'**
  String get deleteSource;

  /// No description provided for @backgroundDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Resolve links in the background and add downloads'**
  String get backgroundDownloadHint;

  /// No description provided for @multiSelect.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get multiSelect;

  /// No description provided for @multiSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select apps to download or favorite in bulk'**
  String get multiSelectHint;

  /// No description provided for @resolvingDownload.
  ///
  /// In en, this message translates to:
  /// **'Resolving download links…'**
  String get resolvingDownload;

  /// No description provided for @filesStartedPartial.
  ///
  /// In en, this message translates to:
  /// **'Files started: {count}, but some links could not be processed'**
  String filesStartedPartial(String count);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @selectedApps.
  ///
  /// In en, this message translates to:
  /// **'Selected apps: {count}'**
  String selectedApps(String count);

  /// No description provided for @favoriteSelectedApps.
  ///
  /// In en, this message translates to:
  /// **'Favorite selected apps'**
  String get favoriteSelectedApps;

  /// No description provided for @downloadSelectedApps.
  ///
  /// In en, this message translates to:
  /// **'Download selected apps'**
  String get downloadSelectedApps;

  /// No description provided for @lookupPackage.
  ///
  /// In en, this message translates to:
  /// **'Find apps by package name'**
  String get lookupPackage;

  /// No description provided for @lookupPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Find by package name'**
  String get lookupPackageTitle;

  /// No description provided for @packageLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Package lookup failed'**
  String get packageLookupFailed;

  /// No description provided for @noMatchingApps.
  ///
  /// In en, this message translates to:
  /// **'No matching apps'**
  String get noMatchingApps;

  /// No description provided for @noPackageSources.
  ///
  /// In en, this message translates to:
  /// **'No sources available for package lookup'**
  String get noPackageSources;

  /// No description provided for @packageSearchedHint.
  ///
  /// In en, this message translates to:
  /// **'Searched enabled package-lookup sources for this package.'**
  String get packageSearchedHint;

  /// No description provided for @enablePackageSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Enable a source that declares package-lookup support first.'**
  String get enablePackageSourceHint;

  /// No description provided for @saveImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get saveImage;

  /// No description provided for @imageRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Image request failed: HTTP {status}'**
  String imageRequestFailed(String status);

  /// No description provided for @imageSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved to gallery'**
  String get imageSaved;

  /// No description provided for @imageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save image: {error}'**
  String imageSaveFailed(String error);

  /// No description provided for @demoSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in demo source for testing APKVision search, details, and downloads.'**
  String get demoSourceDescription;

  /// No description provided for @translationClosed.
  ///
  /// In en, this message translates to:
  /// **'The translation service has been closed'**
  String get translationClosed;

  /// No description provided for @translationEmpty.
  ///
  /// In en, this message translates to:
  /// **'The translation API returned no results'**
  String get translationEmpty;

  /// No description provided for @providerTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'{provider} translation failed: {error}'**
  String providerTranslationFailed(String provider, String error);

  /// No description provided for @shizukuStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read Shizuku status: {error}'**
  String shizukuStatusFailed(String error);

  /// No description provided for @installStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read installation status: {name} · {error}'**
  String installStatusFailed(String name, String error);

  /// No description provided for @appNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'This APK version is not installed or cannot be opened'**
  String get appNotInstalled;

  /// No description provided for @installedAppOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the installed app'**
  String get installedAppOpenFailed;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to restore settings: {error}'**
  String settingsRestoreFailed(String error);

  /// No description provided for @builtInQuickJsSource.
  ///
  /// In en, this message translates to:
  /// **'Built-in QuickJS source'**
  String get builtInQuickJsSource;

  /// No description provided for @downloadsRestored.
  ///
  /// In en, this message translates to:
  /// **'Downloads restored: {count}'**
  String downloadsRestored(String count);

  /// No description provided for @downloadsRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to restore downloads: {error}'**
  String downloadsRestoreFailed(String error);

  /// No description provided for @downloadsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'[APK Mesh] Unable to save downloads: {error}'**
  String downloadsSaveFailed(String error);

  /// No description provided for @downloadSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'Download source unavailable. Import it again and retry.'**
  String get downloadSourceMissing;

  /// No description provided for @scanningSources.
  ///
  /// In en, this message translates to:
  /// **'Scanning built-in QuickJS sources'**
  String get scanningSources;

  /// No description provided for @bundledSourcesFound.
  ///
  /// In en, this message translates to:
  /// **'Built-in source scripts found: {count}'**
  String bundledSourcesFound(String count);

  /// No description provided for @sourceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Source loaded: {path}'**
  String sourceLoaded(String path);

  /// No description provided for @sourceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'QuickJS source failed to load ({path}): {error}'**
  String sourceLoadFailed(String path, String error);

  /// No description provided for @sourceReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the JS source script'**
  String get sourceReadFailed;

  /// No description provided for @sourceImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'QuickJS source import is unavailable on this platform'**
  String get sourceImportUnsupported;

  /// No description provided for @sourceMissingId.
  ///
  /// In en, this message translates to:
  /// **'Source manifest has no valid ID'**
  String get sourceMissingId;

  /// No description provided for @sourceIdExists.
  ///
  /// In en, this message translates to:
  /// **'Source ID already exists: {id}'**
  String sourceIdExists(String id);

  /// No description provided for @sourceHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'Source URL must use HTTPS'**
  String get sourceHttpsRequired;

  /// No description provided for @sourceRuntimeMissing.
  ///
  /// In en, this message translates to:
  /// **'Source runtime not loaded'**
  String get sourceRuntimeMissing;

  /// No description provided for @batchTestStarted.
  ///
  /// In en, this message translates to:
  /// **'Starting batch source tests: search “{query}”'**
  String batchTestStarted(String query);

  /// No description provided for @batchTestFinished.
  ///
  /// In en, this message translates to:
  /// **'Batch tests finished: Available: {available} · Failed: {failed}'**
  String batchTestFinished(String available, String failed);

  /// No description provided for @searchStarted.
  ///
  /// In en, this message translates to:
  /// **'Starting aggregated search: {query}'**
  String searchStarted(String query);

  /// No description provided for @sourceExecutionFailed.
  ///
  /// In en, this message translates to:
  /// **'{source} failed: {error}'**
  String sourceExecutionFailed(String source, String error);

  /// No description provided for @searchFinished.
  ///
  /// In en, this message translates to:
  /// **'Aggregated search finished · Results: {count}'**
  String searchFinished(String count);

  /// No description provided for @packageLookupStarted.
  ///
  /// In en, this message translates to:
  /// **'Starting package lookup: {package}'**
  String packageLookupStarted(String package);

  /// No description provided for @packageLookupFinished.
  ///
  /// In en, this message translates to:
  /// **'Package lookup finished · Results: {count}'**
  String packageLookupFinished(String count);

  /// No description provided for @searchPageStarted.
  ///
  /// In en, this message translates to:
  /// **'Loading search page {page}: {query}'**
  String searchPageStarted(String page, String query);

  /// No description provided for @searchPageFinished.
  ///
  /// In en, this message translates to:
  /// **'Search page {page} finished · Results: {count}'**
  String searchPageFinished(String page, String count);

  /// No description provided for @noAppDetails.
  ///
  /// In en, this message translates to:
  /// **'No app details returned'**
  String get noAppDetails;

  /// No description provided for @candidateNoLinks.
  ///
  /// In en, this message translates to:
  /// **'{name}: No usable download links found'**
  String candidateNoLinks(String name);

  /// No description provided for @wrongHomeSource.
  ///
  /// In en, this message translates to:
  /// **'This catalog tab does not belong to the current home source'**
  String get wrongHomeSource;

  /// No description provided for @sourceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Source is not enabled: {id}'**
  String sourceDisabled(String id);

  /// No description provided for @debugProjectStarted.
  ///
  /// In en, this message translates to:
  /// **'Starting debug project: {name} · {input}'**
  String debugProjectStarted(String name, String input);

  /// No description provided for @debugProjectError.
  ///
  /// In en, this message translates to:
  /// **'Debug project failed: {name} · {error}'**
  String debugProjectError(String name, String error);

  /// No description provided for @notificationInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation from notification failed: {name} · {error}'**
  String notificationInstallFailed(String name, String error);

  /// No description provided for @appStateClosed.
  ///
  /// In en, this message translates to:
  /// **'App state has been closed'**
  String get appStateClosed;

  /// No description provided for @downloadPermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'This source has not declared download permission'**
  String get downloadPermissionMissing;

  /// No description provided for @downloadUrlDenied.
  ///
  /// In en, this message translates to:
  /// **'Source permissions deny access to the download URL'**
  String get downloadUrlDenied;

  /// No description provided for @noExternalDownloader.
  ///
  /// In en, this message translates to:
  /// **'No external downloader available'**
  String get noExternalDownloader;

  /// No description provided for @externalDownloadReceived.
  ///
  /// In en, this message translates to:
  /// **'{method} received: {name}'**
  String externalDownloadReceived(String method, String name);

  /// No description provided for @downloadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting download: {name}'**
  String downloadStarting(String name);

  /// No description provided for @downloadPausing.
  ///
  /// In en, this message translates to:
  /// **'Pausing download: {name}'**
  String downloadPausing(String name);

  /// No description provided for @downloadPauseFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to pause download: {name} · {error}'**
  String downloadPauseFailed(String name, String error);

  /// No description provided for @downloadResuming.
  ///
  /// In en, this message translates to:
  /// **'Resuming download: {name}'**
  String downloadResuming(String name);

  /// No description provided for @downloadResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to resume download: {name} · {error}'**
  String downloadResumeFailed(String name, String error);

  /// No description provided for @downloadCanceling.
  ///
  /// In en, this message translates to:
  /// **'Canceling download: {name}'**
  String downloadCanceling(String name);

  /// No description provided for @downloadCancelCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to clean up canceled download: {name} · {error}'**
  String downloadCancelCleanupFailed(String name, String error);

  /// No description provided for @downloadDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete download file: {name} · {error}'**
  String downloadDeleteFailed(String name, String error);

  /// No description provided for @downloadDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting download: {name}'**
  String downloadDeleting(String name);

  /// No description provided for @downloadSessionCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to clean up download session: {name} · {error}'**
  String downloadSessionCleanupFailed(String name, String error);

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Download completed: {name}'**
  String downloadCompleted(String name);

  /// No description provided for @downloadCanceled.
  ///
  /// In en, this message translates to:
  /// **'Download canceled: {name}'**
  String downloadCanceled(String name);

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {name} · {error}'**
  String downloadError(String name, String error);

  /// No description provided for @downloadNotComplete.
  ///
  /// In en, this message translates to:
  /// **'The download has not finished'**
  String get downloadNotComplete;

  /// No description provided for @installationInProgress.
  ///
  /// In en, this message translates to:
  /// **'This installation is already in progress'**
  String get installationInProgress;

  /// No description provided for @microsoftTranslator.
  ///
  /// In en, this message translates to:
  /// **'Microsoft Edge/Bing'**
  String get microsoftTranslator;

  /// No description provided for @freeTranslator.
  ///
  /// In en, this message translates to:
  /// **'Free translation service'**
  String get freeTranslator;

  /// No description provided for @translationCountMismatch.
  ///
  /// In en, this message translates to:
  /// **'The number of translations does not match the request'**
  String get translationCountMismatch;

  /// No description provided for @microsoftResponseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid Microsoft translation response'**
  String get microsoftResponseInvalid;

  /// No description provided for @freeTranslationResponseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid free translation service response'**
  String get freeTranslationResponseInvalid;

  /// No description provided for @freeTranslationToken.
  ///
  /// In en, this message translates to:
  /// **'Free translation service token'**
  String get freeTranslationToken;

  /// No description provided for @translationTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'The free translation service returned no token'**
  String get translationTokenMissing;

  /// No description provided for @translationJsonInvalid.
  ///
  /// In en, this message translates to:
  /// **'The translation response is not valid JSON: {error}'**
  String translationJsonInvalid(String error);

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// No description provided for @traditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'Traditional Chinese'**
  String get traditionalChinese;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @japaneseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japaneseLanguage;

  /// No description provided for @koreanLanguage.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get koreanLanguage;

  /// No description provided for @spanishLanguage.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanishLanguage;

  /// No description provided for @frenchLanguage.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get frenchLanguage;

  /// No description provided for @germanLanguage.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get germanLanguage;

  /// No description provided for @portugueseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portugueseLanguage;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @appLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Changes the interface only, not the translation language for source content'**
  String get appLanguageHint;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
