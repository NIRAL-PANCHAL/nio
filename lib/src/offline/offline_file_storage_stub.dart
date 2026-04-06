import 'offline_queue_storage.dart';

OfflineQueueStorage createOfflineFileQueueStorageImpl(String absolutePath) {
  throw UnsupportedError(
    'createOfflineFileQueueStorage() is not available on web. '
    'Use MemoryOfflineQueueStorage or implement OfflineQueueStorage yourself.',
  );
}
