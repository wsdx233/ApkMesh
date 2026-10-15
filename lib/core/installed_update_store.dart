import 'installed_update_store_api.dart';

export 'installed_update_store_api.dart';

import 'installed_update_store_stub.dart'
    if (dart.library.io) 'installed_update_store_io.dart'
    as implementation;

InstalledUpdateStore createInstalledUpdateStore() =>
    implementation.createInstalledUpdateStore();
