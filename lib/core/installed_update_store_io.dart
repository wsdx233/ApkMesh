import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'installed_update_store_api.dart';
import 'models.dart';

class _FileInstalledUpdateStore implements InstalledUpdateStore {
  File? _file;

  bool get _isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

  Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return _file ??= File(p.join(directory.path, 'installed-app-updates.json'));
  }

  @override
  Future<InstalledUpdateStoreState> load() async {
    if (_isFlutterTest) return const InstalledUpdateStoreState();
    final file = await _storageFile();
    if (!await file.exists()) return const InstalledUpdateStoreState();

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('应用更新存储格式无效');
    }
    final records = <InstalledAppUpdateRecord>[];
    final rawRecords = decoded['records'];
    if (rawRecords is List) {
      for (final value in rawRecords) {
        if (value is! Map) continue;
        try {
          records.add(
            InstalledAppUpdateRecord.fromJson(Map<String, dynamic>.from(value)),
          );
        } on Object {
          // Ignore one damaged cache record while retaining the queue.
        }
      }
    }
    final rawPending = decoded['pendingKeys'];
    final pendingKeys = rawPending is List
        ? rawPending.whereType<String>().where((key) => key.isNotEmpty).toSet()
        : <String>{};
    return InstalledUpdateStoreState(
      records: List.unmodifiable(records),
      pendingKeys: Set.unmodifiable(pendingKeys),
    );
  }

  @override
  Future<void> save(InstalledUpdateStoreState state) async {
    if (_isFlutterTest) return;
    final file = await _storageFile();
    final temporary = File('${file.path}.tmp');
    final payload = jsonEncode({
      'version': 1,
      'records': state.records.map((record) => record.toJson()).toList(),
      'pendingKeys': state.pendingKeys.toList()..sort(),
    });
    await temporary.writeAsString(payload, flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    }
  }
}

InstalledUpdateStore createInstalledUpdateStore() =>
    _FileInstalledUpdateStore();
