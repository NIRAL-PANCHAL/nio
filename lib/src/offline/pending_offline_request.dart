/// Payload for one request waiting to be replayed when the device is online.
///
/// Serialized by [OfflineQueueStorage] implementations — keep the body JSON-safe
/// (maps, lists, strings, numbers, booleans, null). [FormData] cannot be queued.
class PendingOfflineRequest {
  /// [NioConfig.baseUrl] at the time the request was queued (flush uses this host).
  final String apiBaseUrl;
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? queryParameters;
  final dynamic body;
  final Map<String, dynamic>? extraHeaders;
  final bool requiresAuth;
  final int createdAtMillis;

  const PendingOfflineRequest({
    required this.apiBaseUrl,
    required this.id,
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.body,
    required this.extraHeaders,
    required this.requiresAuth,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toJson() => {
        'apiBaseUrl': apiBaseUrl,
        'id': id,
        'method': method,
        'path': path,
        'queryParameters': queryParameters,
        'body': body,
        'extraHeaders': extraHeaders,
        'requiresAuth': requiresAuth,
        'createdAtMillis': createdAtMillis,
      };

  factory PendingOfflineRequest.fromJson(Map<String, dynamic> json) {
    return PendingOfflineRequest(
      apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      queryParameters: json['queryParameters'] != null
          ? Map<String, dynamic>.from(json['queryParameters'] as Map)
          : null,
      body: json['body'],
      extraHeaders: json['extraHeaders'] != null
          ? Map<String, dynamic>.from(json['extraHeaders'] as Map)
          : null,
      requiresAuth: json['requiresAuth'] as bool? ?? false,
      createdAtMillis: json['createdAtMillis'] as int,
    );
  }
}

/// Summary after [Nio.flushOfflineQueue] runs.
class OfflineFlushResult {
  /// Requests that completed with HTTP success (2xx without parse errors).
  final int succeeded;

  /// Requests that failed again (still in storage unless you clear manually).
  final int failed;

  /// Items left in the queue after the flush attempt.
  final int remaining;

  const OfflineFlushResult({
    required this.succeeded,
    required this.failed,
    required this.remaining,
  });

  static const OfflineFlushResult empty = OfflineFlushResult(
    succeeded: 0,
    failed: 0,
    remaining: 0,
  );
}
