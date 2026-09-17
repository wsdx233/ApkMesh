import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'app_icon.dart';

class AppResultTile extends StatelessWidget {
  const AppResultTile({
    required this.app,
    required this.state,
    this.onOpen,
    this.onEnterSelection,
    this.onSelect,
    this.selectionMode = false,
    this.selected = false,
    this.showDivider = true,
    super.key,
  });

  final AppListing app;
  final AppState state;
  final ValueChanged<AppListing>? onOpen;
  final ValueChanged<AppListing>? onEnterSelection;
  final ValueChanged<AppListing>? onSelect;
  final bool selectionMode;
  final bool selected;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.translationSettings.autoTranslate) {
      state.ensureTranslations([app.name, app.description]);
    }
    final displayName = state.translatedText(app.name) ?? app.name;
    final description =
        state.translatedText(app.description) ?? app.description.trim();
    final chips = buildAppInfoChips(app, compact: true);
    final onTap = selectionMode
        ? (onSelect == null ? null : () => onSelect!(app))
        : (onOpen == null ? null : () => onOpen!(app));

    return Column(
      children: [
        Semantics(
          selected: selectionMode && selected,
          button: onTap != null,
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: .55)
                : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: () => showAppActionMenu(
                context,
                state,
                app,
                onEnterSelection: onEnterSelection,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: 72,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AppIcon(url: app.iconUrl, size: 72, borderRadius: 16),
                          if (selectionMode)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: SizedBox.square(
                                dimension: 28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  child: selected
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                          color: theme.colorScheme.onPrimary,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (chips.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildCompactInfoRows(chips),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 88,
            color: theme.colorScheme.outlineVariant.withValues(alpha: .65),
          ),
      ],
    );
  }
}

enum _AppListAction { download, favorite, select }

Future<void> showAppActionMenu(
  BuildContext context,
  AppState state,
  AppListing app, {
  ValueChanged<AppListing>? onEnterSelection,
}) async {
  final action = await showModalBottomSheet<_AppListAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: AppIcon(url: app.iconUrl, size: 48, borderRadius: 10),
            title: Text(app.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              app.sourceName.trim().isEmpty ? app.sourceId : app.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(AppLocalizations.of(context).downloadAction),
            subtitle: Text(AppLocalizations.of(context).backgroundDownloadHint),
            onTap: () =>
                Navigator.of(sheetContext).pop(_AppListAction.download),
          ),
          ListTile(
            leading: Icon(
              state.isFavorite(app)
                  ? Icons.bookmark_remove_outlined
                  : Icons.bookmark_add_outlined,
            ),
            title: Text(
              state.isFavorite(app)
                  ? AppLocalizations.of(context).unfavorite
                  : AppLocalizations.of(context).favoriteAction,
            ),
            onTap: () =>
                Navigator.of(sheetContext).pop(_AppListAction.favorite),
          ),
          if (onEnterSelection != null)
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(AppLocalizations.of(context).multiSelect),
              subtitle: Text(AppLocalizations.of(context).multiSelectHint),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AppListAction.select),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _AppListAction.download:
      unawaited(_downloadFromListMenu(context, state, app));
    case _AppListAction.favorite:
      state.toggleFavorite(app);
    case _AppListAction.select:
      onEnterSelection?.call(app);
  }
}

Future<void> _downloadFromListMenu(
  BuildContext context,
  AppState state,
  AppListing app,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).resolvingDownload)),
    );
  try {
    final result = await state.downloadApp(app);
    if (!context.mounted || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.hasStarted
                ? result.error == null
                      ? AppLocalizations.of(
                          context,
                        ).filesStarted((result.startedFiles).toString())
                      : AppLocalizations.of(
                          context,
                        ).filesStartedPartial((result.startedFiles).toString())
                : AppLocalizations.of(context).downloadFailed(
                    (result.error ??
                            AppLocalizations.of(context).noDownloadLinks)
                        .toString(),
                  ),
          ),
        ),
      );
  } catch (error) {
    if (!context.mounted || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).cannotStartDownload((error).toString()),
          ),
        ),
      );
  }
}

class AppSelectionToolbar extends StatelessWidget {
  const AppSelectionToolbar({
    required this.selectedCount,
    required this.onClose,
    required this.onDownload,
    required this.onFavorite,
    super.key,
  });

  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).exitSelection,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).selectedApps((selectedCount).toString()),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).favoriteSelectedApps,
            onPressed: onFavorite,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).downloadSelectedApps,
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCompactInfoRows(List<Widget> items) {
  final split = (items.length + 1) ~/ 2;
  final firstRow = items.sublist(0, split);
  final secondRow = items.sublist(split);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(spacing: 12, runSpacing: 4, children: firstRow),
      if (secondRow.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 12, runSpacing: 4, children: secondRow),
      ],
    ],
  );
}

List<Widget> buildAppInfoChips(
  AppListing app, {
  VoidCallback? onPackageTap,
  bool compact = false,
}) {
  final chips = <Widget>[];
  final values = <({IconData icon, String text, Color seedColor})>[];

  void add(IconData icon, String value, Color seedColor) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty &&
        !values.any((item) => item.icon == icon && item.text == trimmed)) {
      values.add((icon: icon, text: trimmed, seedColor: seedColor));
    }
  }

  add(
    Icons.source_outlined,
    app.sourceName.trim().isNotEmpty ? app.sourceName : app.sourceId,
    Colors.blue,
  );
  add(Icons.category_outlined, app.category, Colors.green);
  add(Icons.new_releases_outlined, app.version, Colors.deepPurple);
  add(Icons.storage_outlined, app.size, Colors.deepOrange);
  add(Icons.update_outlined, app.updatedAt, Colors.teal);
  add(Icons.star_outline, app.rating, Colors.amber);
  add(Icons.person_outline, app.author, Colors.indigo);
  add(Icons.code_outlined, app.packageName, Colors.cyan);

  for (final value in values) {
    final onPressed = value.icon == Icons.code_outlined ? onPackageTap : null;
    if (compact) {
      chips.add(
        _AppInfoLabel(icon: value.icon, text: value.text, onPressed: onPressed),
      );
    } else {
      chips.add(
        _AppInfoChip(
          icon: value.icon,
          text: value.text,
          seedColor: value.seedColor,
          onPressed: onPressed,
        ),
      );
    }
  }
  return chips;
}

class _AppInfoLabel extends StatelessWidget {
  const _AppInfoLabel({required this.icon, required this.text, this.onPressed});

  final IconData icon;
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = onPressed == null
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    final label = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    return onPressed == null
        ? label
        : Tooltip(
            message: AppLocalizations.of(context).lookupPackage,
            child: Semantics(
              button: true,
              onTap: onPressed,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPressed,
                child: label,
              ),
            ),
          );
  }
}

class _AppInfoChip extends StatelessWidget {
  const _AppInfoChip({
    required this.icon,
    required this.text,
    required this.seedColor,
    this.onPressed,
  });

  final IconData icon;
  final String text;
  final Color seedColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: theme.brightness,
    );
    final foregroundColor = scheme.onPrimaryContainer;
    final common = ChipTheme.of(context).copyWith(
      labelPadding: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.primaryContainer,
    );

    final chip = Chip(
      avatar: Icon(icon, size: 16, color: foregroundColor),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w600,
      ),
      labelPadding: common.labelPadding,
      padding: common.padding,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      backgroundColor: common.backgroundColor,
      side: common.side,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: onPressed == null
          ? chip
          : Tooltip(
              message: AppLocalizations.of(context).lookupPackage,
              child: Semantics(
                button: true,
                onTap: onPressed,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: chip,
                ),
              ),
            ),
    );
  }
}
