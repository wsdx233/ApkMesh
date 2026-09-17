import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'source_debug_test_sheet.dart';
import 'source_test_sheet.dart';

enum _SourceBulkAction { selectAll, invert, range, enable, disable }

class SourcesPage extends StatefulWidget {
  const SourcesPage({required this.state, super.key});

  final AppState state;

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int? _selectionAnchor;
  int? _rangeEnd;

  AppState get state => widget.state;

  Set<String> get _selectedSourceIds {
    final sourceIds = state.sources.map((source) => source.id).toSet();
    return _selectedIds.intersection(sourceIds);
  }

  Set<String> get _testableSelectedIds => state.sources
      .where(
        (source) =>
            source.status == SourceStatus.enabled &&
            _selectedSourceIds.contains(source.id),
      )
      .map((source) => source.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final sources = state.sources;
    final sourceIds = sources.map((source) => source.id).toSet();
    final selectedSourceIds = _selectedIds.intersection(sourceIds);
    final projectsBySource = <String, List<SourceDebugProject>>{};
    for (final project in state.debugProjects) {
      projectsBySource.putIfAbsent(project.sourceId, () => []).add(project);
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          sliver: SliverToBoxAdapter(child: _buildHeader(context)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          sliver: SliverList.builder(
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return SourceTile(
                key: ValueKey(source.id),
                source: source,
                state: state,
                projects: projectsBySource[source.id] ?? const [],
                selectionMode: _selectionMode,
                selected: selectedSourceIds.contains(source.id),
                onLongPress: () => _enterSelection(index),
                onSelectionToggle: () => _toggleSelection(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final showAllSelectionActions = constraints.maxWidth >= 760;
        final selectionActions = _buildSelectionActions();
        final batchTest = OutlinedButton.icon(
          onPressed: _selectionMode && _testableSelectedIds.isEmpty
              ? null
              : _openBatchTest,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(AppLocalizations.of(context).batchTest),
        );
        final importButton = FilledButton.icon(
          onPressed: () => _showAddSource(context),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context).importSource),
        );
        final title = Text(
          _selectionMode
              ? AppLocalizations.of(
                  context,
                ).selectedSources((_selectedSourceIds.length).toString())
              : AppLocalizations.of(context).sources,
          style: Theme.of(context).textTheme.headlineMedium,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_selectionMode)
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_selectionMode) _buildOverflowMenu(),
                    batchTest,
                    importButton,
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            if (_selectionMode)
              IconButton(
                tooltip: AppLocalizations.of(context).exitSelection,
                onPressed: _exitSelection,
                icon: const Icon(Icons.close),
              ),
            Expanded(child: title),
            if (_selectionMode)
              if (showAllSelectionActions)
                ...selectionActions
              else
                _buildOverflowMenu(),
            batchTest,
            const SizedBox(width: 8),
            importButton,
          ],
        );
      },
    );
  }

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
      tooltip: AppLocalizations.of(context).enableSelectedSources,
      onPressed: _selectedSourceIds.isEmpty
          ? null
          : () => _setSelectedEnabled(true),
      icon: const Icon(Icons.toggle_on_outlined),
    ),
    IconButton(
      tooltip: AppLocalizations.of(context).disableSelectedSources,
      onPressed: _selectedSourceIds.isEmpty
          ? null
          : () => _setSelectedEnabled(false),
      icon: const Icon(Icons.toggle_off_outlined),
    ),
  ];

  Widget _buildOverflowMenu() => PopupMenuButton<_SourceBulkAction>(
    tooltip: AppLocalizations.of(context).bulkActions,
    icon: const Icon(Icons.more_vert),
    onSelected: _handleBulkAction,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: _SourceBulkAction.selectAll,
        child: _BulkActionMenuLabel(
          icon: Icons.select_all,
          label: AppLocalizations.of(context).selectAll,
        ),
      ),
      PopupMenuItem(
        value: _SourceBulkAction.invert,
        child: _BulkActionMenuLabel(
          icon: Icons.swap_vert,
          label: AppLocalizations.of(context).invertSelection,
        ),
      ),
      PopupMenuItem(
        value: _SourceBulkAction.range,
        child: _BulkActionMenuLabel(
          icon: Icons.unfold_more,
          label: AppLocalizations.of(context).selectRange,
        ),
      ),
      PopupMenuItem(
        value: _SourceBulkAction.enable,
        enabled: _selectedSourceIds.isNotEmpty,
        child: _BulkActionMenuLabel(
          icon: Icons.toggle_on_outlined,
          label: AppLocalizations.of(context).enable,
        ),
      ),
      PopupMenuItem(
        value: _SourceBulkAction.disable,
        enabled: _selectedSourceIds.isNotEmpty,
        child: _BulkActionMenuLabel(
          icon: Icons.toggle_off_outlined,
          label: AppLocalizations.of(context).disable,
        ),
      ),
    ],
  );

  void _handleBulkAction(_SourceBulkAction action) {
    switch (action) {
      case _SourceBulkAction.selectAll:
        _selectAll();
      case _SourceBulkAction.invert:
        _invertSelection();
      case _SourceBulkAction.range:
        _selectRange();
      case _SourceBulkAction.enable:
        _setSelectedEnabled(true);
      case _SourceBulkAction.disable:
        _setSelectedEnabled(false);
    }
  }

  void _enterSelection(int index) {
    if (index < 0 || index >= state.sources.length) return;
    setState(() {
      _selectionMode = true;
      _selectedIds.add(state.sources[index].id);
      _selectionAnchor = index;
      _rangeEnd = index;
    });
  }

  void _toggleSelection(int index) {
    if (index < 0 || index >= state.sources.length) return;
    if (!_selectionMode) {
      _enterSelection(index);
      return;
    }
    final id = state.sources[index].id;
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
        ..addAll(state.sources.map((source) => source.id));
      _selectionMode = true;
    });
  }

  void _invertSelection() {
    final allIds = state.sources.map((source) => source.id).toSet();
    final inverted = allIds.difference(_selectedSourceIds);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(inverted);
      _selectionMode = true;
    });
  }

  void _selectRange() {
    if (state.sources.isEmpty) return;
    final anchor =
        _selectionAnchor ??
        state.sources.indexWhere(
          (source) => _selectedSourceIds.contains(source.id),
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
        state.sources.sublist(start, finish + 1).map((source) => source.id),
      );
      _selectionMode = true;
    });
  }

  void _setSelectedEnabled(bool enabled) {
    final selected = _selectedSourceIds;
    if (selected.isEmpty) return;
    state.setSourcesEnabled(selected, enabled);
  }

  void _openBatchTest() {
    if (_selectionMode) {
      final selected = _testableSelectedIds;
      if (selected.isEmpty) return;
      showSourceBatchTestSheet(context, state, sourceIds: selected);
      return;
    }
    showSourceBatchTestSheet(context, state);
  }

  void _showAddSource(BuildContext context) {
    final url = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        String? error;

        return StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) {
            Future<void> runImport(
              Future<SourceImportResult> Function() action,
            ) async {
              setDialogState(() {
                busy = true;
                error = null;
              });
              try {
                final result = await action();
                if (!dialogContext.mounted) return;
                if (result.imported.isEmpty) {
                  setDialogState(() {
                    error = result.failures.entries
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join('\n');
                  });
                  return;
                }
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                final message = result.failures.isEmpty
                    ? AppLocalizations.of(
                        context,
                      ).sourcesImported((result.imported.length).toString())
                    : AppLocalizations.of(context).sourcesImportedWithErrors(
                        (result.imported.length).toString(),
                        (result.failures.length).toString(),
                      );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              } catch (importError) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  error = importError.toString();
                });
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    busy = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(AppLocalizations.of(context).importSource),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: url,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).sourceUrl,
                        hintText: 'https://example.com/source.js',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => runImport(() async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['js', 'zip'],
                                    allowMultiple: false,
                                    withData: true,
                                  );
                              if (result == null) {
                                return const SourceImportResult(
                                  imported: [],
                                  failures: {},
                                );
                              }
                              final file = result.files.single;
                              final bytes =
                                  file.bytes ?? await file.xFile.readAsBytes();
                              return state.importSourceBytes(bytes, file.name);
                            }),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(
                        AppLocalizations.of(context).importSourceFile,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(dialogBuildContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (url.text.trim().isEmpty) {
                            setDialogState(() {
                              error = AppLocalizations.of(
                                context,
                              ).enterSourceUrl;
                            });
                            return;
                          }
                          runImport(() => state.importSourceUrl(url.text));
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(AppLocalizations.of(context).importSourceUrl),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(url.dispose);
  }
}

class _BulkActionMenuLabel extends StatelessWidget {
  const _BulkActionMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
}

class SourceTile extends StatelessWidget {
  const SourceTile({
    required this.source,
    required this.state,
    required this.projects,
    required this.selectionMode,
    required this.selected,
    required this.onLongPress,
    required this.onSelectionToggle,
    super.key,
  });

  final ApkSource source;
  final AppState state;
  final List<SourceDebugProject> projects;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = source.status == SourceStatus.enabled;
    final leading = CircleAvatar(
      child: Icon(source.builtIn ? Icons.inventory_2_outlined : Icons.code),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selectionMode ? onSelectionToggle : null,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: selectionMode
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (_) => onSelectionToggle(),
                          ),
                          leading,
                        ],
                      )
                    : leading,
                title: Text(source.name),
                subtitle: Text(
                  '${source.description}\n${source.homepage} · v${source.version}',
                ),
                isThreeLine: false,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<SourceDebugProject>(
                    tooltip: AppLocalizations.of(context).viewTestProjects,
                    onSelected: (project) =>
                        showSourceDebugTestSheet(context, state, project),
                    itemBuilder: (context) => projects.isEmpty
                        ? [
                            PopupMenuItem<SourceDebugProject>(
                              enabled: false,
                              child: Text(
                                AppLocalizations.of(context).noTestProjects,
                              ),
                            ),
                          ]
                        : projects
                              .map(
                                (project) => PopupMenuItem<SourceDebugProject>(
                                  value: project,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_circle_outline),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(project.name),
                                            if (project.description.isNotEmpty)
                                              Text(
                                                project.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    child: Chip(
                      avatar: Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(AppLocalizations.of(context).test),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    avatar: source.homeSource
                        ? null
                        : const Icon(Icons.home_outlined, size: 18),
                    showCheckmark: true,
                    label: Text(AppLocalizations.of(context).home),
                    selected: source.homeSource,
                    onSelected: enabled
                        ? (selected) {
                            if (selected) state.setHomeSource(source.id);
                          }
                        : null,
                  ),
                  if (!source.builtIn)
                    IconButton(
                      tooltip: AppLocalizations.of(context).deleteSource,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => state.removeSource(source.id),
                    ),
                  const SizedBox(width: 12),
                  Switch(
                    value: enabled,
                    onChanged: (value) => state.toggleSource(source.id, value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
