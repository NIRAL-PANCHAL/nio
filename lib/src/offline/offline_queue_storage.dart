import 'pending_offline_request.dart';

/// Your own persistence layer for the offline queue — no SharedPreferences.
///
/// * [MemoryOfflineQueueStorage] — in RAM (lost when the process exits; good for tests).
/// * [createOfflineFileQueueStorage] — JSON file on disk (VM / Flutter native; not web).
///
/// Implement this interface to plug in Hive, SQLite, encrypted files, etc.
abstract class OfflineQueueStorage {
  /// Load all pending items (FIFO ordering is determined by [PendingOfflineRequest.createdAtMillis]).
  Future<List<PendingOfflineRequest>> loadAll();

  /// Replace the entire queue on disk / in memory.
  Future<void> saveAll(List<PendingOfflineRequest> items);
}
