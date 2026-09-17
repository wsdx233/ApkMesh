import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/debug_log.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';

class SourceDebugTestSheet extends StatefulWidget {
  const SourceDebugTestSheet({
    required this.state,
    required this.project,
    super.key,
  });

  final AppState state;
  final SourceDebugProject project;

  @override
  State<SourceDebugTestSheet> createState() => _SourceDebugTestSheetState();
}

enum _SourceDebugTestStatus { idle, running, succeeded, failed }

class _SourceDebugTestSheetState extends State<SourceDebugTestSheet> {
  late final TextEditingController _inputController;
  _SourceDebugTestStatus _status = _SourceDebugTestStatus.idle;
  DebugProjectResult? _result;
  String? _error;
  DateTime? _startedAt;
  int _runSequence = 0;

  AppState get state => widget.state;
  SourceDebugProject get project => widget.project;
  bool get _running => _status == _SourceDebugTestStatus.running;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: project.defaultInput);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputController.text.trim().isNotEmpty) {
        unawaited(_runProject());
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _runProject() async {
    if (_running) return;
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _status = _SourceDebugTestStatus.idle;
        _result = null;
        _startedAt = null;
        _error = AppLocalizations.of(
          context,
        ).enterValue((project.inputLabel).toString());
      });
      return;
    }

    final sequence = ++_runSequence;
    setState(() {
      _status = _SourceDebugTestStatus.running;
      _result = null;
      _error = null;
      _startedAt = DateTime.now();
    });

    try {
      final result = await state.runDebugProject(project, input);
      if (!mounted || sequence != _runSequence) return;
      setState(() {
        _status = _SourceDebugTestStatus.succeeded;
        _result = result;
      });
    } catch (error) {
      if (!mounted || sequence != _runSequence) return;
      setState(() {
        _status = _SourceDebugTestStatus.failed;
        _error = error.toString();
      });
    }
  }

  ({IconData icon, Color? color, String title, String detail}) _statusView(
    BuildContext context,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;
    return switch (_status) {
      _SourceDebugTestStatus.idle => (
        icon: Icons.play_circle_outline,
        color: null,
        title: AppLocalizations.of(context).waitingForTest,
        detail:
            _error ??
            AppLocalizations.of(
              context,
            ).testInputHint((project.inputLabel).toString()),
      ),
      _SourceDebugTestStatus.running => (
        icon: Icons.sync,
        color: Theme.of(context).colorScheme.primary,
        title: AppLocalizations.of(context).testing,
        detail: AppLocalizations.of(context).testLiveHint,
      ),
      _SourceDebugTestStatus.succeeded => (
        icon: Icons.check_circle_outline,
        color: Colors.green,
        title: AppLocalizations.of(context).testSucceeded,
        detail: _result?.summary ?? AppLocalizations.of(context).testCompleted,
      ),
      _SourceDebugTestStatus.failed => (
        icon: Icons.error_outline,
        color: errorColor,
        title: AppLocalizations.of(context).testFailed,
        detail: _error ?? AppLocalizations.of(context).testIncomplete,
      ),
    };
  }

  List<DebugRequestEntry> _requestsSinceStart() {
    final startedAt = _startedAt;
    if (startedAt == null) return const [];
    return state.debug.requests
        .where((request) => !request.startedAt.isBefore(startedAt))
        .toList(growable: false);
  }

  List<DebugLogEntry> _logsSinceStart() {
    final startedAt = _startedAt;
    if (startedAt == null) return const [];
    return state.debug.entries
        .where((entry) => !entry.time.isBefore(startedAt))
        .toList(growable: false);
  }

  Widget _buildActivity(BuildContext context) {
    final requests = _requestsSinceStart();
    final pending = requests
        .where((request) => request.state == DebugRequestState.pending)
        .length;
    final completed = requests
        .where((request) => request.state == DebugRequestState.completed)
        .length;
    final failed = requests
        .where((request) => request.state == DebugRequestState.failed)
        .length;
    final logs = _logsSinceStart().reversed.take(6).toList(growable: false);

    if (_startedAt == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).liveStatus,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.swap_horiz_outlined),
          title: Text(
            AppLocalizations.of(
              context,
            ).requestCount((requests.length).toString()),
          ),
          subtitle: Text(
            AppLocalizations.of(context).requestStatusCounts(
              (pending).toString(),
              (completed).toString(),
              (failed).toString(),
            ),
          ),
        ),
        if (state.host.browserTabs.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.web_outlined),
            title: Text(
              AppLocalizations.of(
                context,
              ).webViewCount((state.host.browserTabs.length).toString()),
            ),
            subtitle: Text(
              state.host.browserTabs.last.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).recentEvents,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ...logs.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.level == DebugLogLevel.error
                    ? Icons.error_outline
                    : Icons.notes_outlined,
                color: entry.level == DebugLogLevel.error
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(entry.message),
              subtitle: Text(entry.category),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).testResults,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(result.title),
          subtitle: SelectableText(
            '${result.summary}\n${_prettyDebugValue(result.data)}',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusView(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .42,
      maxChildSize: .96,
      builder: (_, controller) => AnimatedBuilder(
        animation: state.debug,
        builder: (context, _) => Material(
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
                            project.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            project.sourceName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).retest,
                      onPressed: _running ? null : _runProject,
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
              if (_running) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(status.icon, color: status.color),
                      title: Text(status.title),
                      subtitle: Text(status.detail),
                    ),
                    if (project.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(project.description),
                      ),
                    TextField(
                      controller: _inputController,
                      enabled: !_running,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_running) unawaited(_runProject());
                      },
                      decoration: InputDecoration(
                        labelText: project.inputLabel,
                        hintText: project.placeholder,
                        suffixIcon: IconButton(
                          tooltip: AppLocalizations.of(context).runTest,
                          onPressed: _running ? null : _runProject,
                          icon: _running
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActivity(context),
                    _buildResult(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showSourceDebugTestSheet(
  BuildContext context,
  AppState state,
  SourceDebugProject project,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SourceDebugTestSheet(state: state, project: project),
  );
}

String _prettyDebugValue(dynamic value) {
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}
