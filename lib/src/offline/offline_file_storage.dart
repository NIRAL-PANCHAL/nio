import 'offline_queue_storage.dart';

import 'offline_file_storage_stub.dart'
    if (dart.library.io) 'offline_file_storage_io.dart' as file_storage;

/// Persist the offline queue as UTF-8 JSON in [absolutePath].
///
/// * Works on **Dart VM** (Flutter mobile/desktop, server-side Dart).
/// * **Throws [UnsupportedError] on web** — use [MemoryOfflineQueueStorage] or a
///   custom [OfflineQueueStorage] (e.g. `window.localStorage` via JS interop).
///
/// Example path: `join(appDocumentsDir.path, 'nio_offline_queue.json')`
OfflineQueueStorage createOfflineFileQueueStorage(String absolutePath) =>
    file_storage.createOfflineFileQueueStorageImpl(absolutePath);
