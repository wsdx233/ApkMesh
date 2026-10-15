import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'app_icon.dart';

String _status(AppState state, AppLocalizations strings) {
  if (state.isCheckingInstalledUpdates) {
    return strings.installedUpdatesChecking(state.pendingInstalledUpdateChecks);
  }
  if (state.lastInstalledUpdateError != null) {
    return strings.updateCheckFailed(state.lastInstalledUpdateError!);
  }
  if (state.lastInstalledUpdateCheck == null) {
    return strings.installedUpdatesNotChecked;
  }
  return strings.installedUpdatesResults(
    state.installedAppUpdates.length,
    state.failedInstalledUpdateChecks,
  );
}

class InstalledAppUpdateSettingsTile extends StatelessWidget {
  const InstalledAppUpdateSettingsTile({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const Icon(Icons.system_update_alt_outlined),
            title: Text(strings.autoCheckInstalledApps),
            subtitle: Text(
              state.host.supportsInstall
                  ? strings.installedAppsUpdateSummary
                  : strings.installUnsupported,
            ),
            value: state.autoCheckInstalledAppUpdates,
            onChanged: state.host.supportsInstall
                ? (value) =>
                      unawaited(state.setAutoCheckInstalledAppUpdates(value))
                : null,
          ),
          if (state.host.supportsInstall)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(strings.installedUpdatesCheckNow),
              subtitle: Text(_status(state, strings)),
              trailing: _CheckButton(state: state),
            ),
        ],
      ),
    );
  }
}

class InstalledAppUpdatesSection extends StatelessWidget {
  const InstalledAppUpdatesSection({
    required this.state,
    this.onOpenDetails,
    super.key,
  });

  final AppState state;
  final void Function(BuildContext context, AppListing app)? onOpenDetails;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final updates = state.installedAppUpdates;
      final strings = AppLocalizations.of(context);
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.system_update_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.installedAppsUpdates,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _CheckButton(state: state),
                ],
              ),
              Text(_status(state, strings)),
              if (!state.autoCheckInstalledAppUpdates)
                Text(strings.installedUpdatesAutomaticOff),
              const SizedBox(height: 6),
              for (final update in updates)
                _UpdateTile(
                  key: ValueKey(update.key),
                  state: state,
                  update: update,
                  onOpenDetails: onOpenDetails,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => state.isCheckingInstalledUpdates
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : IconButton(
          tooltip: AppLocalizations.of(context).installedUpdatesCheckNow,
          onPressed: () =>
              unawaited(state.refreshInstalledAppUpdates(force: true)),
          icon: const Icon(Icons.refresh),
        );
}

class _UpdateTile extends StatefulWidget {
  const _UpdateTile({
    required this.state,
    required this.update,
    this.onOpenDetails,
    super.key,
  });

  final AppState state;
  final InstalledAppUpdateRecord update;
  final void Function(BuildContext context, AppListing app)? onOpenDetails;

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _starting = false;

  Future<void> _download() async {
    final latest = widget.update.latest;
    if (latest == null || _starting) return;
    final strings = AppLocalizations.of(context);
    setState(() => _starting = true);
    try {
      final result = await widget.state.downloadApp(latest);
      if (!mounted) return;
      final message = result.hasStarted
          ? strings.downloadStarted
          : strings.cannotStartDownload(
              result.error ?? strings.noDownloadLinks,
            );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.cannotStartDownload(error.toString())),
          ),
        );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final latest = update.latest!;
    final strings = AppLocalizations.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: AppIcon(url: latest.iconUrl, size: 48, borderRadius: 10),
      title: Text(latest.name),
      subtitle: Text(
        '${latest.sourceName}\n'
        '${strings.currentVersionLabel(update.installed?.versionName ?? "?")} · '
        '${strings.latestVersionLabel(latest.version.trim())}',
      ),
      onTap: widget.onOpenDetails == null
          ? null
          : () => widget.onOpenDetails!(context, latest),
      trailing: FilledButton.tonal(
        onPressed: _starting ? null : () => unawaited(_download()),
        child: _starting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(strings.updateAction),
      ),
    );
  }
}
