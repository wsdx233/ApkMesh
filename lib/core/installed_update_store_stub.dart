import 'installed_update_store_api.dart';

class _MemoryInstalledUpdateStore implements InstalledUpdateStore {
  InstalledUpdateStoreState _state = const InstalledUpdateStoreState();
  @override
  Future<InstalledUpdateStoreState> load() async => _state;

  @override
  Future<void> save(InstalledUpdateStoreState state) async {
    _state = state;
  }
}

InstalledUpdateStore createInstalledUpdateStore() =>
    _MemoryInstalledUpdateStore();
