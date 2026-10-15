import 'models.dart';

class InstalledUpdateStoreState {
  const InstalledUpdateStoreState({
    this.records = const [],
    this.pendingKeys = const {},
  });

  final List<InstalledAppUpdateRecord> records;
  final Set<String> pendingKeys;
}

abstract interface class InstalledUpdateStore {
  Future<InstalledUpdateStoreState> load();

  Future<void> save(InstalledUpdateStoreState state);
}
