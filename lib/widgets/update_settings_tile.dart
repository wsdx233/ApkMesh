import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/app_update.dart';
import '../l10n/app_localizations.dart';
import 'update_dialog.dart';

class UpdateSettingsSection extends StatelessWidget {
  const UpdateSettingsSection({required this.state, super.key});

  final AppState state;

  Future<void> _handleManualCheck(BuildContext context) async {
    if (state.isCheckingUpdate) return;
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final release = await state.checkForUpdates(manual: true);
      if (!context.mounted) return;

      if (release != null && release.hasUpdate(AppVersion.current)) {
        await showUpdateDialog(
          context,
          state: state,
          release: release,
          isManual: true,
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              strings.alreadyLatestVersion(currentAppVersionString),
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(strings.updateCheckFailed(error.toString()))),
      );
    }
  }

  Future<void> _restoreIgnoredVersion(BuildContext context) async {
    final ignored = state.ignoredUpdateVersion;
    if (ignored == null) return;
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await state.clearIgnoredUpdateVersion();
    if (!context.mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text(strings.ignoredVersionRestored(ignored))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final strings = AppLocalizations.of(context);
        final ignored = state.ignoredUpdateVersion;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const ValueKey('setting-auto-check-update'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.sync_outlined),
              title: Text(strings.autoCheckUpdates),
              subtitle: Text(strings.autoCheckUpdatesSummary),
              value: state.autoCheckUpdates,
              onChanged: (value) => state.setAutoCheckUpdates(value),
            ),
            ListTile(
              key: const ValueKey('setting-check-for-updates'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.system_update_alt_outlined),
              title: Text(strings.checkForUpdates),
              subtitle: Text(
                state.isCheckingUpdate
                    ? strings.checkingForUpdates
                    : strings.currentVersionLabel(currentAppVersionString),
              ),
              trailing: state.isCheckingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: state.isCheckingUpdate
                  ? null
                  : () => _handleManualCheck(context),
            ),
            if (ignored != null)
              ListTile(
                key: const ValueKey('setting-ignored-update-version'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(strings.ignoredVersionHint(ignored)),
                trailing: IconButton(
                  tooltip: strings.restoreDefaults,
                  icon: const Icon(Icons.restore),
                  onPressed: () => _restoreIgnoredVersion(context),
                ),
                onTap: () => _restoreIgnoredVersion(context),
              ),
          ],
        );
      },
    );
  }
}
