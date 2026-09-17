import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

class SourceBatchTestSheet extends StatefulWidget {
  const SourceBatchTestSheet({required this.state, this.sourceIds, super.key});

  final AppState state;
  final Set<String>? sourceIds;

  @override
  State<SourceBatchTestSheet> createState() => _SourceBatchTestSheetState();
}

class _SourceBatchTestSheetState extends State<SourceBatchTestSheet> {
  static const _query = 'hello';

  late List<ApkSource> _sources;
  final Map<String, SourceTestResult> _results = {};
  String? _error;
  bool _loading = true;

  AppState get state => widget.state;

  List<ApkSource> _testableSources() => state.sources
      .where(
        (source) =>
            source.status == SourceStatus.enabled &&
            (widget.sourceIds == null || widget.sourceIds!.contains(source.id)),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _sources = _testableSources();
    unawaited(_runTest());
  }

  Future<void> _runTest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _results.clear();
      _sources = _testableSources();
    });
    try {
      final results = await state.testAllSources(
        query: _query,
        sourceIds: widget.sourceIds,
        onResult: (result) {
          if (!mounted) return;
          setState(() => _results[result.sourceId] = result);
        },
      );
      if (!mounted) return;
      setState(() {
        _results.addEntries(
          results.map((result) => MapEntry(result.sourceId, result)),
        );
        _sources = _testableSources();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SourceTestResult> get _failedResults => _results.values
      .where((result) => !result.succeeded)
      .toList(growable: false);

  List<SourceTestResult> get _failedEnabledResults {
    final sourceStatuses = {
      for (final source in state.sources) source.id: source.status,
    };
    return _failedResults
        .where(
          (result) => sourceStatuses[result.sourceId] != SourceStatus.disabled,
        )
        .toList(growable: false);
  }

  Future<void> _disableFailedSources() async {
    final failed = _failedEnabledResults;
    if (failed.isEmpty) return;
    final shouldDisable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).disableFailedTitle),
        content: Text(
          AppLocalizations.of(
            context,
          ).disableFailedMessage((failed.length).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context).disableSources),
          ),
        ],
      ),
    );
    if (shouldDisable != true || !mounted) return;
    final disabledIds = failed.map((result) => result.sourceId).toSet();
    state.disableSources(disabledIds);
    setState(() {
      _results.removeWhere((sourceId, _) => disabledIds.contains(sourceId));
      _sources = _testableSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    final failed = _failedResults.length;
    final failedEnabled = _failedEnabledResults.length;
    final succeeded = _results.values
        .where((result) => result.succeeded)
        .length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .5,
      maxChildSize: .96,
      builder: (_, controller) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).batchTestSources,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          AppLocalizations.of(context).batchTestQuery(
                            (_query).toString(),
                            (_sources.length).toString(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).retest,
                    onPressed: _loading ? null : _runTest,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                minHeight: 2,
                value: _sources.isEmpty
                    ? null
                    : _results.length / _sources.length,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _loading
                          ? AppLocalizations.of(context).batchTestProgress(
                              (_results.length).toString(),
                              (_sources.length).toString(),
                              (succeeded).toString(),
                              (failed).toString(),
                            )
                          : AppLocalizations.of(context).batchTestCounts(
                              (succeeded).toString(),
                              (failed).toString(),
                            ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (!_loading && failedEnabled > 0)
                    FilledButton.icon(
                      onPressed: _disableFailedSources,
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(
                        AppLocalizations.of(
                          context,
                        ).disableFailedSources((failedEnabled).toString()),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: _sources.length + (_error == null ? 0 : 1),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (_error != null && index == 0) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        AppLocalizations.of(context).batchTestIncomplete,
                      ),
                      subtitle: Text(_error!),
                    );
                  }
                  final sourceIndex = _error == null ? index : index - 1;
                  final source = _sources[sourceIndex];
                  return _SourceTestTile(
                    source: source,
                    result: _results[source.id],
                    loading: _loading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTestTile extends StatelessWidget {
  const _SourceTestTile({
    required this.source,
    required this.result,
    required this.loading,
  });

  final ApkSource source;
  final SourceTestResult? result;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (IconData icon, Color? color, String subtitle) = switch (result) {
      null when loading => (
        Icons.hourglass_empty,
        null,
        AppLocalizations.of(context).waitingForTest,
      ),
      null => (
        Icons.help_outline,
        null,
        AppLocalizations.of(context).notTested,
      ),
      final value when value.succeeded => (
        Icons.check_circle_outline,
        Colors.green,
        AppLocalizations.of(
          context,
        ).sourceTestAvailable((value.resultCount).toString()),
      ),
      final value => (
        Icons.error_outline,
        colorScheme.error,
        AppLocalizations.of(
          context,
        ).sourceTestUnavailable((value.error).toString()),
      ),
    };
    final statusSuffix =
        source.status == SourceStatus.disabled && result?.succeeded == true
        ? AppLocalizations.of(context).sourceCurrentlyDisabled
        : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(source.name),
      subtitle: Text('$subtitle$statusSuffix'),
      trailing: source.builtIn
          ? const Icon(Icons.inventory_2_outlined, size: 20)
          : const Icon(Icons.code_outlined, size: 20),
    );
  }
}

void showSourceBatchTestSheet(
  BuildContext context,
  AppState state, {
  Set<String>? sourceIds,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SourceBatchTestSheet(state: state, sourceIds: sourceIds),
  );
}
