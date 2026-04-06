import 'offline_queue_storage.dart';
import 'pending_offline_request.dart';

/// Enables the offline queue in [NioConfig].
///
/// * [storage] — **your** persistence: memory, file, or custom.
/// * [defaultQueueWhenOffline] — when `true`, eligible methods queue on connection
///   loss without setting [NioOptions.queueWhenOffline] on every call.
/// * [queueableMethods] — defaults to mutations only (`POST`, `PUT`, `PATCH`, `DELETE`).
///   Add `GET` only if you intentionally want to replay reads (rare).
class OfflineQueueSettings {
  /// Where pending calls are loaded/saved.
  final OfflineQueueStorage storage;

  /// If true, matching failed requests are queued when [NioOptions.queueWhenOffline]
  /// is also true **or** when this default is true globally.
  final bool defaultQueueWhenOffline;

  /// Hard cap to avoid unbounded growth.
  final int maxPending;

  /// Which HTTP verbs may be stored (uppercase).
  final Set<String> queueableMethods;

  final void Function(PendingOfflineRequest request)? onRequestQueued;

  const OfflineQueueSettings({
    required this.storage,
    this.defaultQueueWhenOffline = false,
    this.maxPending = 200,
    this.queueableMethods = const {'POST', 'PUT', 'PATCH', 'DELETE'},
    this.onRequestQueued,
  });
}
