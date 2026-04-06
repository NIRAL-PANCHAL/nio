import 'offline_queue_storage.dart';
import 'pending_offline_request.dart';

/// In-memory queue — no I/O, fully under your control.
///
/// Survives for the lifetime of the process. For persistence across restarts,
/// use [createOfflineFileQueueStorage] on native platforms or provide your own
/// [OfflineQueueStorage].
class MemoryOfflineQueueStorage implements OfflineQueueStorage {
  final List<PendingOfflineRequest> _items = [];

  @override
  Future<List<PendingOfflineRequest>> loadAll() async => List.from(_items);

  @override
  Future<void> saveAll(List<PendingOfflineRequest> items) async {
    _items
      ..clear()
      ..addAll(items);
  }

  /// Current length without copying (for quick UI badges).
  int get length => _items.length;
}
