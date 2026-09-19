import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/app_update.dart';
import '../l10n/app_localizations.dart';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = -1;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final digits = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

Future<void> showUpdateDialog(
  BuildContext context, {
  required AppState state,
  required AppReleaseInfo release,
  bool isManual = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) =>
        UpdateDialog(state: state, release: release, isManual: isManual),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    required this.state,
    required this.release,
    this.isManual = false,
    super.key,
  });

  final AppState state;
  final AppReleaseInfo release;
  final bool isManual;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  bool _installing = false;
  double? _progress;
  int _received = 0;
  int? _total;
  String? _errorMessage;
  http.Client? _downloadClient;

  @override
  void dispose() {
    _downloadClient?.close();
    super.dispose();
  }

  void _cancelDownload() {
    _downloadClient?.close();
    _downloadClient = null;
    if (mounted) {
      setState(() {
        _downloading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final asset = widget.release.apkAsset;
    final urlString = asset?.downloadUrl.isNotEmpty == true
        ? asset!.downloadUrl
        : widget.release.htmlUrl;
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startUpdate() async {
    final asset = widget.release.apkAsset;
    if (asset == null || asset.downloadUrl.isEmpty) {
      await _openInBrowser();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _downloading = true;
      _errorMessage = null;
      _received = 0;
      _total = asset.size > 0 ? asset.size : null;
      _progress = null;
    });

    final client = http.Client();
    _downloadClient = client;

    try {
      final file = await widget.state.updateService.downloadApk(
        asset,
        client: client,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
            if (total != null && total > 0) {
              _progress = received / total;
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _installing = true;
      });

      if (Platform.isAndroid || widget.state.host.supportsInstall) {
        try {
          final result = await OpenFilex.open(
            file.path,
            type: 'application/vnd.android.package-archive',
          );
          if (result.type == ResultType.done && mounted) {
            Navigator.of(context).pop();
            return;
          }
        } catch (_) {
          // If OpenFilex fails, fall through to browser or completion
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _installing = false;
        _errorMessage = error.toString();
      });
    } finally {
      client.close();
      if (_downloadClient == client) {
        _downloadClient = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asset = widget.release.apkAsset;
    final bodyText = widget.release.body?.trim();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.newVersionAvailable,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    strings.currentVersionLabel(currentAppVersionString),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.release.tagName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (asset != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${asset.name}${asset.size > 0 ? ' · ${_formatBytes(asset.size)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                strings.releaseNotes,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    bodyText != null && bodyText.isNotEmpty
                        ? bodyText
                        : strings.noReleaseNotes,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              if (_downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.downloadingUpdate(
                        _progress != null
                            ? (_progress! * 100).toStringAsFixed(0)
                            : '...',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_total != null)
                      Text(
                        '${_formatBytes(_received)} / ${_formatBytes(_total!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              if (_installing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.downloadCompleteInstalling,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  strings.downloadUpdateFailed(_errorMessage!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_downloading && !_installing) ...[
          TextButton(
            key: const ValueKey('update-dialog-dont-remind'),
            onPressed: () {
              widget.state.setIgnoredUpdateVersion(widget.release.tagName);
              Navigator.of(context).pop();
            },
            child: Text(strings.dontRemindAgain),
          ),
          TextButton(
            key: const ValueKey('update-dialog-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
          FilledButton(
            key: const ValueKey('update-dialog-update'),
            onPressed: _startUpdate,
            child: Text(strings.updateAction),
          ),
        ] else if (_downloading) ...[
          TextButton(
            key: const ValueKey('update-dialog-browser'),
            onPressed: _openInBrowser,
            child: Text(strings.openInBrowser),
          ),
          TextButton(
            key: const ValueKey('update-dialog-cancel'),
            onPressed: _cancelDownload,
            child: Text(strings.close),
          ),
        ],
      ],
    );
  }
}
