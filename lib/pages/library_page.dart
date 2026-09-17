import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_result_tile.dart';
import '../widgets/empty_message.dart';
import 'details_sheet.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.bookmark_outline),
                text: AppLocalizations.of(context).favorites,
              ),
              Tab(
                icon: Icon(Icons.history),
                text: AppLocalizations.of(context).history,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _LibraryList(state: state, history: false),
              _LibraryList(state: state, history: true),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LibraryList extends StatefulWidget {
  const _LibraryList({required this.state, required this.history});

  final AppState state;
  final bool history;

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
  final Map<String, AppListing> _selectedApps = {};
  bool _selectionMode = false;

  List<AppListing> get apps =>
      widget.history ? widget.state.history : widget.state.favorites;

  String _appKey(AppListing app) => '${app.sourceId}\u0000${app.id}';

  bool _isSelected(AppListing app) => _selectedApps.containsKey(_appKey(app));

  void _enterSelection(AppListing app) {
    setState(() {
      _selectionMode = true;
      _selectedApps[_appKey(app)] = app;
    });
  }

  void _toggleSelection(AppListing app) {
    final key = _appKey(app);
    setState(() {
      if (_selectedApps.remove(key) == null) _selectedApps[key] = app;
    });
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedApps.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedApps.clear();
    });
  }

  void _favoriteSelected() {
    final added = widget.state.favoriteApps(_selectedApps.values);
    _exitSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? AppLocalizations.of(context).alreadyFavorites
              : AppLocalizations.of(context).appsFavorited((added).toString()),
        ),
      ),
    );
  }

  void _downloadSelected() {
    final selected = _selectedApps.values.toList(growable: false);
    if (selected.isEmpty) return;
    _exitSelection();
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).resolvingDownloadsBackground,
          ),
        ),
      );
    unawaited(_runBatchDownload(selected, messenger));
  }

  Future<void> _runBatchDownload(
    List<AppListing> selected,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final result = await widget.state.downloadApps(selected);
      if (!mounted || !messenger.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.startedFiles == 0
                  ? AppLocalizations.of(context).batchDownloadNoLinks
                  : result.appsWithErrors == 0
                  ? AppLocalizations.of(
                      context,
                    ).filesStarted((result.startedFiles).toString())
                  : AppLocalizations.of(context).filesStartedWithErrors(
                      (result.startedFiles).toString(),
                      (result.appsWithErrors).toString(),
                    ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted || !messenger.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).batchDownloadFailed((error).toString()),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = apps;
    final content = items.isEmpty
        ? ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              _buildHeader(context, 0),
              const SizedBox(height: 20),
              EmptyMessage(
                icon: widget.history ? Icons.history : Icons.bookmark_border,
                title: widget.history
                    ? AppLocalizations.of(context).noHistory
                    : AppLocalizations.of(context).noFavorites,
                detail: widget.history
                    ? AppLocalizations.of(context).noHistoryHint
                    : AppLocalizations.of(context).noFavoritesHint,
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader(context, items.length);
              final app = items[index - 1];
              return AppResultTile(
                key: ValueKey('${app.sourceId}:${app.id}'),
                app: app,
                state: widget.state,
                onOpen: (selected) =>
                    showAppDetails(context, widget.state, selected),
                onEnterSelection: _enterSelection,
                onSelect: _toggleSelection,
                selectionMode: _selectionMode,
                selected: _isSelected(app),
                showDivider: index < items.length,
              );
            },
          );

    return Column(
      children: [
        if (_selectionMode)
          AppSelectionToolbar(
            selectedCount: _selectedApps.length,
            onClose: _exitSelection,
            onDownload: _downloadSelected,
            onFavorite: _favoriteSelected,
          ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int count) => Row(
    children: [
      Expanded(
        child: Text(
          widget.history
              ? AppLocalizations.of(context).browsingHistory
              : AppLocalizations.of(context).myFavorites,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      Text(
        '$count',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: widget.history
            ? AppLocalizations.of(context).clearHistory
            : AppLocalizations.of(context).clearFavorites,
        onPressed: count == 0 ? null : () => _confirmClear(context),
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ],
  );

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.history
              ? AppLocalizations.of(context).clearHistoryTitle
              : AppLocalizations.of(context).clearFavoritesTitle,
        ),
        content: Text(
          widget.history
              ? AppLocalizations.of(context).clearHistoryMessage
              : AppLocalizations.of(context).clearFavoritesMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context).clearLibrary),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (widget.history) {
      widget.state.clearHistory();
    } else {
      widget.state.clearFavorites();
    }
  }
}
