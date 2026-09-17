import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_language.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/translation_service.dart';
import '../l10n/app_localizations.dart';

const _settingsTilePadding = EdgeInsets.symmetric(horizontal: 16);
const _settingsControlWidth = 152.0;
final _githubRepositoryUri = Uri.parse('https://github.com/wsdx233/ApkMesh');

String _themeModeLabel(AppThemeMode mode, AppLocalizations strings) =>
    switch (mode) {
      AppThemeMode.system => strings.followSystem,
      AppThemeMode.light => strings.lightTheme,
      AppThemeMode.dark => strings.darkTheme,
    };

String _downloadMethodLabel(DownloadMethod method, AppLocalizations strings) =>
    switch (method) {
      DownloadMethod.internal => strings.internalDownload,
      DownloadMethod.browser => strings.browser,
      DownloadMethod.externalDownloader => strings.externalDownloader,
    };

class _AppLanguageSettingsTile extends StatelessWidget {
  const _AppLanguageSettingsTile({required this.state});

  final AppState state;

  String _label(AppLanguage language, AppLocalizations strings) =>
      switch (language) {
        AppLanguage.system => strings.followSystem,
        AppLanguage.chinese => strings.languageChinese,
        AppLanguage.english => strings.languageEnglish,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('app-language-setting'),
      contentPadding: _settingsTilePadding,
      leading: const Icon(Icons.language),
      title: Text(strings.appLanguage),
      subtitle: Text(_label(state.appLanguage, strings)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) {
          final strings = AppLocalizations.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.appLanguage,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(strings.appLanguageHint),
                const SizedBox(height: 12),
                RadioGroup<AppLanguage>(
                  groupValue: state.appLanguage,
                  onChanged: (language) {
                    if (language == null) return;
                    unawaited(state.setAppLanguage(language));
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      for (final language in AppLanguage.values)
                        RadioListTile<AppLanguage>(
                          key: ValueKey('app-language-${language.preference}'),
                          contentPadding: EdgeInsets.zero,
                          value: language,
                          title: Text(_label(language, strings)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: _settingsTilePadding,
                  child: Text(
                    AppLocalizations.of(context).settings,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 20),
                _AppLanguageSettingsTile(state: state),
                const Divider(),
                ListTile(
                  contentPadding: _settingsTilePadding,
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(AppLocalizations.of(context).theme),
                  subtitle: Text(
                    _themeModeLabel(
                      state.themeMode,
                      AppLocalizations.of(context),
                    ),
                  ),
                  trailing: SizedBox(
                    width: _settingsControlWidth,
                    child: DropdownButton<AppThemeMode>(
                      isExpanded: true,
                      value: state.themeMode,
                      onChanged: (value) {
                        if (value != null) state.setThemeMode(value);
                      },
                      items: [
                        for (final mode in AppThemeMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(
                              _themeModeLabel(
                                mode,
                                AppLocalizations.of(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                _DownloadMethodSettingsTile(state: state),
                const Divider(),
                _InformationSettingsTile(
                  icon: Icons.folder_outlined,
                  title: AppLocalizations.of(context).downloadDirectory,
                  subtitle: AppLocalizations.of(
                    context,
                  ).downloadDirectorySummary,
                  paragraphs: [
                    AppLocalizations.of(context).downloadDirectoryInternal,
                    AppLocalizations.of(context).downloadDirectoryExternal,
                  ],
                ),
                const Divider(),
                _SourceConcurrencySettingsTile(state: state),
                const Divider(),
                TranslationSettingsPanel(state: state),
                const Divider(),
                ListTile(
                  contentPadding: _settingsTilePadding,
                  leading: const Icon(Icons.security_outlined),
                  title: Text(AppLocalizations.of(context).installPermission),
                  subtitle: Text(
                    state.host.supportsInstall
                        ? AppLocalizations.of(context).installPermissionSummary
                        : AppLocalizations.of(context).installUnsupported,
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: state.host.supportsInstall
                      ? state.host.requestInstallPermission
                      : () => _showInformationSheet(
                          context,
                          icon: Icons.security_outlined,
                          title: AppLocalizations.of(context).installPermission,
                          paragraphs: [
                            AppLocalizations.of(
                              context,
                            ).installPermissionDetails,
                          ],
                        ),
                ),
                if (state.host.supportsShizuku) ...[
                  const Divider(),
                  _ShizukuInstallationSettingsPanel(state: state),
                ],
                const Divider(),
                _InformationSettingsTile(
                  icon: Icons.policy_outlined,
                  title: AppLocalizations.of(context).legalSafety,
                  subtitle: AppLocalizations.of(context).legalSafetySummary,
                  paragraphs: [
                    AppLocalizations.of(context).legalAuthorization,
                    AppLocalizations.of(context).legalVerification,
                    AppLocalizations.of(context).legalPermissions,
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: _settingsTilePadding,
                  leading: const Icon(Icons.code),
                  title: Text(AppLocalizations.of(context).githubProject),
                  subtitle: Text(AppLocalizations.of(context).githubSummary),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openGitHubRepository(context),
                ),
                const Divider(),
                _InformationSettingsTile(
                  icon: Icons.info_outline,
                  title: AppLocalizations.of(context).aboutApp,
                  subtitle: AppLocalizations.of(context).aboutSummary,
                  paragraphs: [
                    AppLocalizations.of(context).aboutDescription,
                    AppLocalizations.of(context).appVersion,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _openGitHubRepository(BuildContext context) async {
  try {
    final launched = await launchUrl(
      _githubRepositoryUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) return;
  } catch (_) {
    // The same user-facing message covers unavailable and failing handlers.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).githubOpenFailed)),
  );
}

class _DownloadMethodSettingsTile extends StatelessWidget {
  const _DownloadMethodSettingsTile({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: _settingsTilePadding,
    leading: const Icon(Icons.download_for_offline_outlined),
    title: Text(AppLocalizations.of(context).downloadMethod),
    subtitle: Text(
      _downloadMethodLabel(state.downloadMethod, AppLocalizations.of(context)),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DownloadMethodSheet(state: state),
    ),
  );
}

class _DownloadMethodSheet extends StatelessWidget {
  const _DownloadMethodSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).downloadMethod,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RadioGroup<DownloadMethod>(
              groupValue: state.downloadMethod,
              onChanged: (method) {
                if (method == null) return;
                state.setDownloadMethod(method);
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  RadioListTile<DownloadMethod>(
                    contentPadding: EdgeInsets.zero,
                    value: DownloadMethod.internal,
                    secondary: Icon(Icons.download_outlined),
                    title: Text(AppLocalizations.of(context).internalDownload),
                    subtitle: Text(
                      AppLocalizations.of(context).internalDownloadHint,
                    ),
                  ),
                  RadioListTile<DownloadMethod>(
                    contentPadding: EdgeInsets.zero,
                    value: DownloadMethod.browser,
                    secondary: Icon(Icons.open_in_browser_outlined),
                    title: Text(AppLocalizations.of(context).browser),
                    subtitle: Text(
                      AppLocalizations.of(context).browserDownloadHint,
                    ),
                  ),
                  RadioListTile<DownloadMethod>(
                    contentPadding: EdgeInsets.zero,
                    value: DownloadMethod.externalDownloader,
                    enabled: state.supportsExternalDownloader,
                    secondary: const Icon(Icons.move_to_inbox_outlined),
                    title: Text(
                      AppLocalizations.of(context).externalDownloader,
                    ),
                    subtitle: Text(
                      state.supportsExternalDownloader
                          ? AppLocalizations.of(context).externalDownloaderHint
                          : AppLocalizations.of(
                              context,
                            ).externalDownloaderUnsupported,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InformationSettingsTile extends StatelessWidget {
  const _InformationSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: _settingsTilePadding,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _showInformationSheet(
      context,
      icon: icon,
      title: title,
      paragraphs: paragraphs,
    ),
  );
}

void _showInformationSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required List<String> paragraphs,
}) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < paragraphs.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                SelectableText(
                  paragraphs[index],
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SourceConcurrencySettingsTile extends StatelessWidget {
  const _SourceConcurrencySettingsTile({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.sourceConcurrency;
    return ListTile(
      contentPadding: _settingsTilePadding,
      leading: const Icon(Icons.speed_outlined),
      title: Text(AppLocalizations.of(context).sourceConcurrency),
      subtitle: Text(
        'HTTP ${settings.httpRequests} · WebView ${settings.webViews}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _SourceConcurrencySheet(state: state),
      ),
    );
  }
}

class _SourceConcurrencySheet extends StatefulWidget {
  const _SourceConcurrencySheet({required this.state});

  final AppState state;

  @override
  State<_SourceConcurrencySheet> createState() =>
      _SourceConcurrencySheetState();
}

class _SourceConcurrencySheetState extends State<_SourceConcurrencySheet> {
  late int _httpRequests;
  late int _webViews;
  late final TextEditingController _httpController;
  late final TextEditingController _webViewController;

  @override
  void initState() {
    super.initState();
    final settings = widget.state.sourceConcurrency;
    _httpRequests = settings.httpRequests;
    _webViews = settings.webViews;
    _httpController = TextEditingController(text: '$_httpRequests');
    _webViewController = TextEditingController(text: '$_webViews');
  }

  @override
  void dispose() {
    _httpController.dispose();
    _webViewController.dispose();
    super.dispose();
  }

  int? _positiveValue(TextEditingController controller) {
    final value = int.tryParse(controller.text);
    return value == null || value < 1 ? null : value;
  }

  bool get _valid =>
      _positiveValue(_httpController) != null &&
      _positiveValue(_webViewController) != null;

  void _setHttpRequests(int value) {
    setState(() {
      _httpRequests = math.max(1, value);
      _httpController.text = '$_httpRequests';
    });
  }

  void _setWebViews(int value) {
    setState(() {
      _webViews = math.max(1, value);
      _webViewController.text = '$_webViews';
    });
  }

  void _readHttpRequests(String _) {
    final value = _positiveValue(_httpController);
    setState(() {
      if (value != null) _httpRequests = value;
    });
  }

  void _readWebViews(String _) {
    final value = _positiveValue(_webViewController);
    setState(() {
      if (value != null) _webViews = value;
    });
  }

  void _restoreDefaults() {
    _setHttpRequests(SourceConcurrencySettings.defaultHttpRequests);
    _setWebViews(SourceConcurrencySettings.defaultWebViews);
  }

  void _apply() {
    final httpRequests = _positiveValue(_httpController);
    final webViews = _positiveValue(_webViewController);
    if (httpRequests == null || webViews == null) return;
    widget.state.setSourceConcurrency(
      httpRequests: httpRequests,
      webViews: webViews,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).sourceConcurrency,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ConcurrencyControl(
                  icon: Icons.language_outlined,
                  title: AppLocalizations.of(context).httpRequests,
                  subtitle: AppLocalizations.of(context).httpConcurrencyHint,
                  value: _httpRequests,
                  baselineMax: 100,
                  controller: _httpController,
                  onSliderChanged: (value) => _setHttpRequests(value.round()),
                  onTextChanged: _readHttpRequests,
                ),
                const Divider(height: 40),
                _ConcurrencyControl(
                  icon: Icons.web_asset_outlined,
                  title: AppLocalizations.of(context).headlessWebView,
                  subtitle: AppLocalizations.of(context).webViewConcurrencyHint,
                  value: _webViews,
                  baselineMax: 10,
                  controller: _webViewController,
                  onSliderChanged: (value) => _setWebViews(value.round()),
                  onTextChanged: _readWebViews,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _restoreDefaults,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(AppLocalizations.of(context).restoreDefaults),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _valid ? _apply : null,
                      icon: const Icon(Icons.check),
                      label: Text(AppLocalizations.of(context).apply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConcurrencyControl extends StatelessWidget {
  const _ConcurrencyControl({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.baselineMax,
    required this.controller,
    required this.onSliderChanged,
    required this.onTextChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final double baselineMax;
  final TextEditingController controller;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valid = (int.tryParse(controller.text) ?? 0) >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 112,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.end,
                onChanged: onTextChanged,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).concurrency,
                  errorText: valid
                      ? null
                      : AppLocalizations.of(context).minimumOne,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            year2023: false,
            trackHeight: 24,
            trackGap: 8,
            activeTrackColor: scheme.primary,
            inactiveTrackColor: scheme.primaryContainer,
            thumbColor: scheme.primary,
            overlayColor: scheme.primary.withValues(alpha: .12),
          ),
          child: Slider(
            value: math.min(value.toDouble(), baselineMax),
            min: 1,
            max: baselineMax,
            label: '$value',
            onChanged: onSliderChanged,
          ),
        ),
      ],
    );
  }
}

String _shizukuStatusLabel(
  ShizukuStatus status,
  bool enabled,
  AppLocalizations strings,
) => switch (status) {
  ShizukuStatus.authorized =>
    enabled
        ? strings.shizukuAuthorizedEnabled
        : strings.shizukuAuthorizedDisabled,
  ShizukuStatus.unavailable =>
    enabled
        ? strings.shizukuNotRunningEnabled
        : strings.shizukuNotRunningDisabled,
  ShizukuStatus.denied => strings.shizukuDenied,
  ShizukuStatus.unsupported => strings.shizukuUnsupported,
};

class _ShizukuInstallationSettingsPanel extends StatefulWidget {
  const _ShizukuInstallationSettingsPanel({required this.state});

  final AppState state;

  @override
  State<_ShizukuInstallationSettingsPanel> createState() =>
      _ShizukuInstallationSettingsPanelState();
}

class _ShizukuInstallationSettingsPanelState
    extends State<_ShizukuInstallationSettingsPanel> {
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.state.refreshShizukuStatus());
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _changing = true);
    try {
      final changed = await widget.state.setUseShizukuInstaller(enabled);
      if (!changed && mounted) {
        final message = _shizukuStatusLabel(
          widget.state.shizukuStatus,
          false,
          AppLocalizations.of(context),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).shizukuAuthorizationFailed((error).toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: _settingsTilePadding,
    secondary: const Icon(Icons.admin_panel_settings_outlined),
    title: Text(AppLocalizations.of(context).useShizuku),
    subtitle: Text(
      _shizukuStatusLabel(
        widget.state.shizukuStatus,
        widget.state.useShizukuInstaller,
        AppLocalizations.of(context),
      ),
    ),
    value: widget.state.useShizukuInstaller,
    onChanged: _changing ? null : _setEnabled,
  );
}

class TranslationSettingsPanel extends StatelessWidget {
  const TranslationSettingsPanel({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.translationSettings;
    return ListTile(
      contentPadding: _settingsTilePadding,
      leading: const Icon(Icons.translate_outlined),
      title: Text(AppLocalizations.of(context).translation),
      subtitle: Text(
        '${settings.provider.label(AppLocalizations.of(context))} · ${translationLanguageLabel(settings.targetLanguage, AppLocalizations.of(context))}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _TranslationSettingsSheet(state: state),
      ),
    );
  }
}

class _TranslationSettingsSheet extends StatefulWidget {
  const _TranslationSettingsSheet({required this.state});

  final AppState state;

  @override
  State<_TranslationSettingsSheet> createState() =>
      _TranslationSettingsSheetState();
}

class _TranslationSettingsSheetState extends State<_TranslationSettingsSheet> {
  late final TextEditingController _googleKeyController;

  @override
  void initState() {
    super.initState();
    _googleKeyController = TextEditingController(
      text: widget.state.translationSettings.googlePublicKey,
    );
  }

  @override
  void didUpdateWidget(covariant _TranslationSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = widget.state.translationSettings.googlePublicKey;
    if (_googleKeyController.text != key) {
      _googleKeyController.text = key;
    }
  }

  @override
  void dispose() {
    _googleKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final settings = widget.state.translationSettings;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.translate_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).translationSettings,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).close,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).autoTranslate),
                      subtitle: Text(
                        AppLocalizations.of(context).autoTranslateHint,
                      ),
                      value: settings.autoTranslate,
                      onChanged: widget.state.setAutoTranslate,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        AppLocalizations.of(context).translationService,
                      ),
                      trailing: SizedBox(
                        width: _settingsControlWidth,
                        child: DropdownButton<TranslationProvider>(
                          isExpanded: true,
                          value: settings.provider,
                          onChanged: (value) {
                            if (value != null) {
                              widget.state.setTranslationProvider(value);
                            }
                          },
                          items: [
                            for (final provider in TranslationProvider.values)
                              DropdownMenuItem(
                                value: provider,
                                child: Text(
                                  provider.label(AppLocalizations.of(context)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context).targetLanguage),
                      trailing: SizedBox(
                        width: _settingsControlWidth,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: settings.targetLanguage,
                          onChanged: (value) {
                            if (value != null) {
                              widget.state.setTranslationLanguage(value);
                            }
                          },
                          items: [
                            for (final language in const [
                              'system',
                              'zh-CN',
                              'zh-TW',
                              'en',
                              'ja',
                              'ko',
                              'es',
                              'fr',
                              'de',
                              'pt',
                            ])
                              DropdownMenuItem(
                                value: language,
                                child: Text(
                                  translationLanguageLabel(
                                    language,
                                    AppLocalizations.of(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (settings.provider == TranslationProvider.google) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _googleKeyController,
                        obscureText: true,
                        onEditingComplete: () => widget.state
                            .setGooglePublicKey(_googleKeyController.text),
                        onSubmitted: widget.state.setGooglePublicKey,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).googleApiKey,
                          helperText: AppLocalizations.of(
                            context,
                          ).googleApiKeyHint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context).translationPrivacy,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
