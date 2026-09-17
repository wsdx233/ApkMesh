import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_result_tile.dart';
import '../widgets/empty_message.dart';

enum _DownloadBulkAction {
  selectAll,
  invert,
  range,
  pause,
  resume,
  cancel,
  retry,
  delete,
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({required this.state, this.onOpenDetails, super.key});
  final AppState state;
  final void Function(BuildContext context, AppListing app)? onOpenDetails;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int? _selectionAnchor;
  int? _rangeEnd;

  AppState get state => widget.state;

  Set<String> get _selectedDownloadIds {
    final downloadIds = state.downloads.map((task) => task.id).toSet();
    return _selectedIds.intersection(downloadIds);
  }

  List<DownloadTask> get _selectedTasks => state.downloads
      .where((task) => _selectedDownloadIds.contains(task.id))
      .toList(growable: false);

  List<DownloadTask> _selectedTasksWithStatus(
    Set<DownloadStatus> statuses, {
    bool excludeInstalling = false,
  }) => _selectedTasks
      .where(
        (task) =>
            statuses.contains(task.status) &&
            (!excludeInstalling || !state.isInstallingDownload(task.id)),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final tasks = state.downloads;
    final completedCount = tasks
        .where((task) => task.status == DownloadStatus.completed)
        .length;
    final selectedIds = _selectedDownloadIds;
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildHeader(context, tasks, completedCount),
        ),
        const SizedBox(height: 20),
        if (tasks.isEmpty)
          EmptyMessage(
            icon: Icons.download_done_outlined,
            title: AppLocalizations.of(context).noDownloads,
            detail: AppLocalizations.of(context).noDownloadsHint,
          )
        else
          ...tasks.asMap().entries.map(
            (entry) => DownloadTaskTile(
              key: ValueKey(entry.value.id),
              task: entry.value,
              state: state,
              onOpenDetails: widget.onOpenDetails,
              selectionMode: _selectionMode,
              selected: selectedIds.contains(entry.value.id),
              onLongPress: () => _enterSelection(entry.key),
              onSelectionToggle: () => _toggleSelection(entry.key),
              showDivider: entry.key < tasks.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<DownloadTask> tasks,
    int completedCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final showAllSelectionActions = constraints.maxWidth >= 760;
        final title = Text(
          _selectionMode
              ? AppLocalizations.of(
                  context,
                ).selectedDownloads((_selectedDownloadIds.length).toString())
              : AppLocalizations.of(context).downloadManager,
          style: Theme.of(context).textTheme.headlineMedium,
        );

        if (!_selectionMode) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              _buildClearMenu(context, tasks, completedCount),
            ],
          );
        }

        final selectionActions = _buildSelectionActions();
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: AppLocalizations.of(context).exitSelection,
                    onPressed: _exitSelection,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _buildOverflowMenu(),
              ),
            ],
          );
        }

        return Row(
          children: [
            IconButton(
              tooltip: AppLocalizations.of(context).exitSelection,
              onPressed: _exitSelection,
              icon: const Icon(Icons.close),
            ),
            Expanded(child: title),
            if (showAllSelectionActions)
              ...selectionActions
            else
              _buildOverflowMenu(),
          ],
        );
      },
    );
  }

  Widget _buildClearMenu(
    BuildContext context,
    List<DownloadTask> tasks,
    int completedCount,
  ) => PopupMenuButton<DownloadClearAction>(
    enabled: tasks.isNotEmpty,
    tooltip: AppLocalizations.of(context).cleanDownloads,
    icon: const Icon(Icons.delete_sweep_outlined),
    onSelected: (action) => confirmClearDownloads(context, state, action),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: DownloadClearAction.all,
        child: Text(AppLocalizations.of(context).clearAll),
      ),
      PopupMenuItem(
        value: DownloadClearAction.completed,
        enabled: completedCount > 0,
        child: Text(AppLocalizations.of(context).clearCompleted),
      ),
    ],
  );

  List<Widget> _buildSelectionActions() => [
    IconButton(
      tooltip: AppLocalizations.of(context).selectAll,
      onPressed: _selectAll,
      icon: const Icon(Icons.select_all),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).invertSelection,
      onPressed: _invertSelection,
      icon: const Icon(Icons.swap_vert),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).selectRange,
      onPressed: _selectRange,
      icon: const Icon(Icons.unfold_more),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).pauseSelectedDownloads,
      onPressed: _selectedTasksWithStatus({DownloadStatus.downloading}).isEmpty
          ? null
          : () => unawaited(_pauseSelected()),
      icon: const Icon(Icons.pause_circle_outline),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).resumeSelectedDownloads,
      onPressed: _selectedTasksWithStatus({DownloadStatus.paused}).isEmpty
          ? null
          : () => unawaited(_resumeSelected()),
      icon: const Icon(Icons.play_circle_outline),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).cancelSelectedDownloads,
      onPressed:
          _selectedTasksWithStatus({
            DownloadStatus.downloading,
            DownloadStatus.paused,
          }).isEmpty
          ? null
          : () => unawaited(_cancelSelected()),
      icon: const Icon(Icons.cancel_outlined),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).retrySelectedDownloads,
      onPressed: _selectedTasksWithStatus({DownloadStatus.failed}).isEmpty
          ? null
          : _retrySelected,
      icon: const Icon(Icons.refresh),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).deleteSelectedDownloads,
      onPressed:
          _selectedTasksWithStatus({
            DownloadStatus.completed,
            DownloadStatus.failed,
          }, excludeInstalling: true).isEmpty
          ? null
          : () => unawaited(_deleteSelected()),
      icon: const Icon(Icons.delete_outline),
    ),
  ];

  Widget _buildOverflowMenu() => PopupMenuButton<_DownloadBulkAction>(
    tooltip: AppLocalizations.of(context).bulkActions,
    icon: const Icon(Icons.more_vert),
    onSelected: _handleBulkAction,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _DownloadBulkAction.selectAll,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.select_all,
          label: AppLocalizations.of(context).selectAll,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.invert,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.swap_vert,
          label: AppLocalizations.of(context).invertSelection,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.range,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.unfold_more,
          label: AppLocalizations.of(context).selectRange,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.pause,
        enabled: _selectedTasksWithStatus({
          DownloadStatus.downloading,
        }).isNotEmpty,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.pause_circle_outline,
          label: AppLocalizations.of(context).pauseSelectedDownloads,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.resume,
        enabled: _selectedTasksWithStatus({DownloadStatus.paused}).isNotEmpty,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.play_circle_outline,
          label: AppLocalizations.of(context).resumeSelectedDownloads,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.cancel,
        enabled: _selectedTasksWithStatus({
          DownloadStatus.downloading,
          DownloadStatus.paused,
        }).isNotEmpty,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.cancel_outlined,
          label: AppLocalizations.of(context).cancelSelectedDownloads,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.retry,
        enabled: _selectedTasksWithStatus({DownloadStatus.failed}).isNotEmpty,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.refresh,
          label: AppLocalizations.of(context).retrySelectedDownloads,
        ),
      ),
      PopupMenuItem(
        value: _DownloadBulkAction.delete,
        enabled: _selectedTasksWithStatus({
          DownloadStatus.completed,
          DownloadStatus.failed,
        }, excludeInstalling: true).isNotEmpty,
        child: _DownloadBulkActionMenuLabel(
          icon: Icons.delete_outline,
          label: AppLocalizations.of(context).deleteSelectedDownloads,
        ),
      ),
    ],
  );

  void _handleBulkAction(_DownloadBulkAction action) {
    switch (action) {
      case _DownloadBulkAction.selectAll:
        _selectAll();
      case _DownloadBulkAction.invert:
        _invertSelection();
      case _DownloadBulkAction.range:
        _selectRange();
      case _DownloadBulkAction.pause:
        unawaited(_pauseSelected());
      case _DownloadBulkAction.resume:
        unawaited(_resumeSelected());
      case _DownloadBulkAction.cancel:
        unawaited(_cancelSelected());
      case _DownloadBulkAction.retry:
        _retrySelected();
      case _DownloadBulkAction.delete:
        unawaited(_deleteSelected());
    }
  }

  void _enterSelection(int index) {
    if (index < 0 || index >= state.downloads.length) return;
    setState(() {
      _selectionMode = true;
      _selectedIds.add(state.downloads[index].id);
      _selectionAnchor = index;
      _rangeEnd = index;
    });
  }

  void _toggleSelection(int index) {
    if (index < 0 || index >= state.downloads.length) return;
    if (!_selectionMode) {
      _enterSelection(index);
      return;
    }
    final id = state.downloads[index].id;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
      _rangeEnd = index;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _selectionAnchor = null;
      _rangeEnd = null;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(state.downloads.map((task) => task.id));
      _selectionMode = true;
    });
  }

  void _invertSelection() {
    final allIds = state.downloads.map((task) => task.id).toSet();
    final inverted = allIds.difference(_selectedDownloadIds);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(inverted);
      _selectionMode = true;
    });
  }

  void _selectRange() {
    if (state.downloads.isEmpty) return;
    final anchor =
        _selectionAnchor ??
        state.downloads.indexWhere(
          (task) => _selectedDownloadIds.contains(task.id),
        );
    final end = _rangeEnd ?? anchor;
    if (anchor < 0 || end < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).selectRangeHint)),
      );
      return;
    }
    final start = anchor < end ? anchor : end;
    final finish = anchor < end ? end : anchor;
    setState(() {
      _selectedIds.addAll(
        state.downloads.sublist(start, finish + 1).map((task) => task.id),
      );
      _selectionMode = true;
    });
  }

  Future<void> _pauseSelected() async {
    final tasks = _selectedTasksWithStatus({DownloadStatus.downloading});
    await _applyToTasks(tasks, state.pauseDownload);
  }

  Future<void> _resumeSelected() async {
    final tasks = _selectedTasksWithStatus({DownloadStatus.paused});
    await _applyToTasks(tasks, state.resumeDownload);
  }

  Future<void> _cancelSelected() async {
    final tasks = _selectedTasksWithStatus({
      DownloadStatus.downloading,
      DownloadStatus.paused,
    });
    if (tasks.isEmpty) return;
    final confirmed = await _confirmBulkAction(
      title: AppLocalizations.of(context).cancelSelectedTitle,
      content: AppLocalizations.of(
        context,
      ).cancelSelectedMessage((tasks.length).toString()),
      confirmLabel: AppLocalizations.of(context).cancelDownload,
    );
    if (confirmed != true || !mounted) return;
    await _applyToTasks(tasks, state.cancelDownload);
  }

  void _retrySelected() {
    final tasks = _selectedTasksWithStatus({DownloadStatus.failed});
    for (final task in tasks) {
      state.retryDownload(task);
    }
  }

  Future<void> _deleteSelected() async {
    final tasks = _selectedTasksWithStatus({
      DownloadStatus.completed,
      DownloadStatus.failed,
    }, excludeInstalling: true);
    if (tasks.isEmpty) return;
    final confirmed = await _confirmBulkAction(
      title: AppLocalizations.of(context).deleteSelectedTitle,
      content: AppLocalizations.of(
        context,
      ).deleteSelectedMessage((tasks.length).toString()),
      confirmLabel: AppLocalizations.of(context).delete,
    );
    if (confirmed != true || !mounted) return;
    await _applyToTasks(tasks, state.deleteDownload);
  }

  Future<void> _applyToTasks(
    List<DownloadTask> tasks,
    Future<void> Function(DownloadTask task) action,
  ) async {
    if (tasks.isEmpty) return;
    await Future.wait(tasks.map(action));
    _pruneSelection();
  }

  Future<bool?> _confirmBulkAction({
    required String title,
    required String content,
    required String confirmLabel,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  void _pruneSelection() {
    if (!mounted) return;
    final available = state.downloads.map((task) => task.id).toSet();
    final before = _selectedIds.length;
    _selectedIds.retainAll(available);
    if (_selectedIds.length == before) return;
    if (_selectedIds.isEmpty) {
      _exitSelection();
    } else {
      setState(() {});
    }
  }
}

class _DownloadBulkActionMenuLabel extends StatelessWidget {
  const _DownloadBulkActionMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
}

enum DownloadClearAction { all, completed }

Future<void> confirmClearDownloads(
  BuildContext context,
  AppState state,
  DownloadClearAction action,
) async {
  final completedOnly = action == DownloadClearAction.completed;
  final count = state.downloads
      .where(
        (task) => !completedOnly || task.status == DownloadStatus.completed,
      )
      .length;
  if (count == 0) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        completedOnly
            ? AppLocalizations.of(context).clearCompletedTitle
            : AppLocalizations.of(context).clearAllDownloadsTitle,
      ),
      content: Text(
        completedOnly
            ? AppLocalizations.of(
                context,
              ).clearCompletedMessage((count).toString())
            : AppLocalizations.of(
                context,
              ).clearAllDownloadsMessage((count).toString()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(AppLocalizations.of(context).clear),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await state.clearDownloads(completedOnly: completedOnly);
  }
}

Future<void> confirmDeleteDownload(
  BuildContext context,
  AppState state,
  DownloadTask task,
) async {
  if (task.status != DownloadStatus.completed &&
      task.status != DownloadStatus.failed) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.of(context).deleteDownloadTitle),
      content: Text(
        AppLocalizations.of(
          context,
        ).deleteDownloadMessage((task.file.label).toString()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(AppLocalizations.of(context).delete),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await state.deleteDownload(task);
  }
}

class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({
    required this.task,
    required this.state,
    this.onOpenDetails,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.onSelectionToggle,
    this.showDivider = true,
    super.key,
  });

  final DownloadTask task;
  final AppState state;
  final void Function(BuildContext context, AppListing app)? onOpenDetails;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (task.status) {
      DownloadStatus.downloading => (Icons.downloading, scheme.primary),
      DownloadStatus.paused => (Icons.pause_circle_outline, scheme.tertiary),
      DownloadStatus.completed => (Icons.check_circle_outline, scheme.primary),
      DownloadStatus.failed => (Icons.error_outline, scheme.error),
      DownloadStatus.canceled => (Icons.cancel_outlined, scheme.outline),
    };
    final detail = downloadTaskDetail(task, AppLocalizations.of(context));
    final app = task.app;
    final appName = app?.name.trim() ?? '';
    final appDescription = app?.description.trim() ?? '';
    final appInfo = app == null
        ? const <Widget>[]
        : buildAppInfoChips(app, compact: true);
    final hasAppIcon = app?.iconUrl.trim().isNotEmpty ?? false;
    final leadingWidth = hasAppIcon ? 72.0 : 40.0;
    final selectionLeadingWidth = hasAppIcon ? 120.0 : 72.0;
    final leadingGap = hasAppIcon ? 16.0 : 12.0;
    final openDetailsCallback = onOpenDetails;
    final openDetails = app == null || openDetailsCallback == null
        ? null
        : () => openDetailsCallback(context, app);
    final leadingContent = hasAppIcon
        ? AppIcon(url: app!.iconUrl, size: 64, borderRadius: 14)
        : Align(
            alignment: Alignment.topLeft,
            child: Icon(icon, color: color),
          );
    final leading = selectionMode
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: selected,
                onChanged: onSelectionToggle == null
                    ? null
                    : (_) => onSelectionToggle!(),
              ),
              leadingContent,
            ],
          )
        : leadingContent;

    return Column(
      children: [
        Material(
          color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
          child: InkWell(
            key: ValueKey('download-task-tile-${task.id}'),
            onTap: selectionMode ? onSelectionToggle : openDetails,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: selectionMode ? selectionLeadingWidth : leadingWidth,
                    child: leading,
                  ),
                  SizedBox(width: leadingGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName.isEmpty ? task.file.label : appName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (appDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            appDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        if (appInfo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 12, runSpacing: 4, children: appInfo),
                        ],
                        if (appName.isNotEmpty &&
                            task.file.label.trim() != appName) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.file.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        DownloadTaskControls(
                          task: task,
                          state: state,
                          onOpenDetails: onOpenDetails,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .65),
          ),
      ],
    );
  }
}

class DownloadTaskControls extends StatefulWidget {
  const DownloadTaskControls({
    required this.task,
    required this.state,
    this.onOpenDetails,
    super.key,
  });

  final DownloadTask task;
  final AppState state;
  final void Function(BuildContext context, AppListing app)? onOpenDetails;

  @override
  State<DownloadTaskControls> createState() => _DownloadTaskControlsState();
}

class _DownloadTaskControlsState extends State<DownloadTaskControls> {
  @override
  void initState() {
    super.initState();
    _refreshInstallState();
  }

  @override
  void didUpdateWidget(covariant DownloadTaskControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.status != widget.task.status ||
        oldWidget.task.filePath != widget.task.filePath) {
      _refreshInstallState();
    }
  }

  void _refreshInstallState() {
    final task = widget.task;
    if (task.status == DownloadStatus.completed && task.filePath != null) {
      unawaited(widget.state.refreshInstallState(task));
    }
  }

  Future<void> _openInstalled() async {
    try {
      await widget.state.openInstalledTask(widget.task);
    } catch (error) {
      if (mounted) {
        showActionErrorSnackBar(
          context,
          summary: AppLocalizations.of(context).openFailed,
          error: error,
        );
      }
    }
  }

  Widget _completedActionRow(
    BuildContext context,
    AppState state,
    DownloadTask task,
    Widget primaryAction,
  ) {
    final onOpenDetails = widget.onOpenDetails;
    final app = task.app;
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).deleteDownload,
            color: Theme.of(context).colorScheme.error,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            onPressed: () => confirmDeleteDownload(context, state, task),
            icon: const Icon(Icons.delete_outline),
          ),
          if (app != null && onOpenDetails != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: AppLocalizations.of(context).openDetails,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onPressed: () => onOpenDetails(context, app),
              icon: const Icon(Icons.article_outlined),
            ),
          ],
          const SizedBox(width: 4),
          primaryAction,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final state = widget.state;
    switch (task.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.paused:
        final paused = task.status == DownloadStatus.paused;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: paused
                  ? AppLocalizations.of(context).resumeDownload
                  : AppLocalizations.of(context).pauseDownload,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onPressed: () => paused
                  ? state.resumeDownload(task)
                  : state.pauseDownload(task),
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).cancelDownload,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onPressed: () => state.cancelDownload(task),
              icon: const Icon(Icons.close),
            ),
          ],
        );
      case DownloadStatus.completed:
        final installInfo = state.installInfoFor(task.id);
        if (state.isInstallingDownload(task.id)) {
          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 88,
              height: 40,
              child: FilledButton(
                onPressed: null,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        if (installInfo?.versionMatches == true) {
          return _completedActionRow(
            context,
            state,
            task,
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(AppLocalizations.of(context).open),
              onPressed: _openInstalled,
            ),
          );
        }
        return _completedActionRow(
          context,
          state,
          task,
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.install_mobile_outlined),
            label: Text(AppLocalizations.of(context).install),
            onPressed: () => installDownloadTask(context, state, task),
          ),
        );
      case DownloadStatus.failed:
        return Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).deleteDownload,
                color: Theme.of(context).colorScheme.error,
                onPressed: () => confirmDeleteDownload(context, state, task),
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).retryDownload,
                onPressed: () => state.retryDownload(task),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      case DownloadStatus.canceled:
        return const SizedBox.shrink();
    }
  }
}

String? downloadTaskDetail(DownloadTask task, AppLocalizations strings) {
  switch (task.status) {
    case DownloadStatus.downloading:
      final total = task.total;
      final progress = total != null && total > 0
          ? '${formatByteCount(task.received)} / ${formatByteCount(total)} · ${((task.progress ?? 0) * 100).toStringAsFixed(0)}%'
          : task.received > 0
          ? strings.downloadedBytes((formatByteCount(task.received)).toString())
          : strings.connecting;
      final stats = <String>[];
      final speed = task.speedBytesPerSecond;
      if (speed != null && speed > 0) {
        stats.add(strings.downloadSpeed((formatByteCount(speed)).toString()));
      }
      final remaining = task.estimatedRemaining;
      if (remaining != null) {
        stats.add(
          strings.remainingTime(
            (formatDownloadDuration(remaining, strings)).toString(),
          ),
        );
      }
      return [progress, ...stats].join(' · ');
    case DownloadStatus.paused:
      final progress = task.received > 0
          ? strings.downloadedBytes((formatByteCount(task.received)).toString())
          : strings.transferNotStarted;
      return strings.pausedProgress((progress).toString());
    case DownloadStatus.completed:
      return null;
    case DownloadStatus.failed:
      return strings.downloadFailedDetail(
        (task.error ?? strings.unknownError).toString(),
      );
    case DownloadStatus.canceled:
      return strings.canceled;
  }
}

String formatByteCount(int bytes) {
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

String formatDownloadDuration(Duration duration, AppLocalizations strings) {
  final totalSeconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = totalSeconds % 3600 ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return minutes > 0
        ? strings.hoursMinutes((hours).toString(), (minutes).toString())
        : strings.hours((hours).toString());
  }
  if (minutes > 0) {
    return seconds > 0
        ? strings.minutesSeconds((minutes).toString(), (seconds).toString())
        : strings.minutes((minutes).toString());
  }
  return strings.seconds((seconds).toString());
}

Future<void> installDownloadTask(
  BuildContext context,
  AppState state,
  DownloadTask task,
) async {
  try {
    final useShizuku = state.useShizukuInstaller;
    final installed = await state.installTask(task);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          installed
              ? useShizuku
                    ? AppLocalizations.of(context).installedWithShizuku
                    : AppLocalizations.of(context).sentToInstaller
              : AppLocalizations.of(context).installationIncomplete,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    showActionErrorSnackBar(
      context,
      summary: AppLocalizations.of(context).installationFailed,
      error: error,
    );
  }
}

void showActionErrorSnackBar(
  BuildContext context, {
  required String summary,
  required Object error,
}) {
  final detail = error.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(summary),
        action: SnackBarAction(
          label: AppLocalizations.of(context).details,
          onPressed: () {
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  AppLocalizations.of(
                    context,
                  ).errorDetails((summary).toString()),
                ),
                content: SingleChildScrollView(child: SelectableText(detail)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(AppLocalizations.of(context).close),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
}
