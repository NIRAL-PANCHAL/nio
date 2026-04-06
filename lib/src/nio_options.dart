import 'package:dio/dio.dart';

/// Internal keys used to pass [NioOptions] through Dio's `extra` map.
const String nioOptionsKey = '_nio_options';
const String retryCountKey = '_nio_retry_count';
const String authRetryKey = '_nio_auth_retry';

/// Per-request configuration.
///
/// Pass to any Nio method to override global defaults for that call.
class NioOptions {
  /// Attach the bearer token to this request.
  final bool requiresAuth;

  /// How many times to retry on network / 5xx errors (0 = no retry).
  final int maxRetries;

  /// Base delay between retries. Actual delay doubles each attempt.
  final Duration retryDelay;

  /// Serve from memory cache if available (GET only).
  final bool cache;

  /// How long a cached response stays valid.
  final Duration cacheTtl;

  /// If true **and** [NioConfig.showError] is set, show a UI message on error.
  final bool showErrorMessage;

  /// Merged with global headers for this request only.
  final Map<String, dynamic>? extraHeaders;

  /// Override connect + receive timeout for this request.
  final Duration? timeout;

  /// Attach a [CancelToken] to abort this request.
  final CancelToken? cancelToken;

  /// When [NioConfig.offlineQueue] is set, store this call if the device has no
  /// connection ([DioExceptionType.connectionError]) and the method is queueable.
  ///
  /// Overrides [OfflineQueueSettings.defaultQueueWhenOffline] for this call only.
  final bool queueWhenOffline;

  const NioOptions({
    this.requiresAuth = false,
    this.maxRetries = 0,
    this.retryDelay = const Duration(milliseconds: 500),
    this.cache = false,
    this.cacheTtl = const Duration(minutes: 5),
    this.showErrorMessage = true,
    this.extraHeaders,
    this.timeout,
    this.cancelToken,
    this.queueWhenOffline = false,
  });

  NioOptions copyWith({
    bool? requiresAuth,
    int? maxRetries,
    Duration? retryDelay,
    bool? cache,
    Duration? cacheTtl,
    bool? showErrorMessage,
    Map<String, dynamic>? extraHeaders,
    Duration? timeout,
    CancelToken? cancelToken,
    bool? queueWhenOffline,
  }) {
    return NioOptions(
      requiresAuth: requiresAuth ?? this.requiresAuth,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      cache: cache ?? this.cache,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      showErrorMessage: showErrorMessage ?? this.showErrorMessage,
      extraHeaders: extraHeaders ?? this.extraHeaders,
      timeout: timeout ?? this.timeout,
      cancelToken: cancelToken ?? this.cancelToken,
      queueWhenOffline: queueWhenOffline ?? this.queueWhenOffline,
    );
  }
}
