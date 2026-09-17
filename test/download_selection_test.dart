import 'package:apk_mesh/core/app_state.dart';
import 'package:apk_mesh/core/models.dart';
import 'package:apk_mesh/core/source_runtime.dart';
import 'package:apk_mesh/l10n/app_localizations.dart';
import 'package:apk_mesh/pages/downloads_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('supports long press selection and bulk download management', (
    tester,
  ) async {
    final state = _SelectionState([
      _task('download-1', DownloadStatus.completed),
      _task('download-2', DownloadStatus.paused),
      _task('download-3', DownloadStatus.failed),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DownloadsPage(state: state)),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey('download-task-tile-download-1')),
    );
    await tester.pump();
    expect(find.byTooltip('退出多选'), findsOneWidget);
    expect(find.text('已选择 1 个下载'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('download-task-tile-download-3')),
    );
    await tester.tap(
      find.byKey(const ValueKey('download-task-tile-download-3')),
    );
    await tester.pump();
    expect(find.text('已选择 2 个下载'), findsOneWidget);

    final overflow = find.byTooltip('批量管理');
    expect(overflow, findsOneWidget);
    await tester.tap(overflow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('区间选择'));
    await tester.pump();
    expect(find.text('已选择 3 个下载'), findsOneWidget);

    await tester.tap(find.byTooltip('批量管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除选中下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('删除选中的下载？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.deletedIds, containsAll(<String>['download-1', 'download-3']));
    expect(find.text('已选择 1 个下载'), findsOneWidget);

    await tester.tap(find.byTooltip('批量管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(find.text('已选择 1 个下载'), findsOneWidget);
    state.dispose();
  });
}

DownloadTask _task(String id, DownloadStatus status) => DownloadTask(
  id: id,
  file: SourceDownload(
    label: '$id.apk',
    url: 'https://example.test/$id.apk',
    size: '1 MB',
  ),
  sourceId: 'example-source',
  status: status,
  startedAt: DateTime(2026, 1, 1),
  policy: const DownloadPolicySnapshot(
    allowedHosts: ['example.test'],
    allowInstall: true,
  ),
  filePath: status == DownloadStatus.completed ? '/tmp/$id.apk' : null,
);

class _SelectionState extends AppState {
  _SelectionState(List<DownloadTask> tasks)
    : _tasks = List.of(tasks),
      super(host: DemoHostApi());

  final List<DownloadTask> _tasks;
  final List<String> deletedIds = [];

  @override
  List<DownloadTask> get downloads => List.unmodifiable(_tasks);

  @override
  bool isInstallingDownload(String downloadId) => false;

  @override
  Future<void> refreshInstallState(DownloadTask task) async {}

  @override
  Future<void> deleteDownload(DownloadTask task) async {
    deletedIds.add(task.id);
    _tasks.removeWhere((item) => item.id == task.id);
  }
}
