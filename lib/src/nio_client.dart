import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_result.dart';
import 'error_handler.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'nio_config.dart';
import 'nio_error.dart';
import 'nio_mock.dart';
import 'nio_options.dart';
import 'offline/pending_offline_request.dart';

/// The main entry point for all network calls.
///
/// ```dart
/// // 1. Create once (usually in a service locator)
/// final nio = Nio(config: NioConfig(baseUrl: 'https://api.example.com'));
///
/// // 2. Call APIs
/// final result = await nio.get<User>('/profile', fromJson: User.fromJson);
///
/// // 3. Handle the result
/// result.when(
///   success: (user) => print(user.name),
///   failure: (err) => print(err.userMessage),
/// );
/// ```
class Nio {
  late final Dio _dio;
  final NioConfig config;

  final NioMockInterceptor _mockInterceptor = NioMockInterceptor();
  late final CacheInterceptor _cacheInterceptor;

  int _offlineIdSeq = 0;

  Nio({required this.config}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...config.headers,
        },
      ),
    );

    _cacheInterceptor = CacheInterceptor();

    // Order matters:
    //  1. Mock   — short-circuit before anything else during testing
    //  2. Auth   — attach token; handle 401 → refresh → retry
    //  3. Retry  — retry network / 5xx errors with backoff
    //  4. Cache  — serve from / store to memory cache
    //  5. Log    — last so it sees the final request & response
    _dio.interceptors.add(_mockInterceptor);

    if (config.tokenProvider != null) {
      _dio.interceptors.add(AuthInterceptor(
        tokenProvider: config.tokenProvider!,
        refreshToken: config.refreshToken,
        dio: _dio,
      ));
    }

    _dio.interceptors.add(RetryInterceptor(dio: _dio));
    _dio.interceptors.add(_cacheInterceptor);

    if (config.enableLogging) {
      _dio.interceptors.add(NioLoggingInterceptor());
    }
  }

  /// Escape hatch — use for anything Nio doesn't cover directly.
  Dio get dio => _dio;

  // ══════════════════════════════════════════════════════════════════
  // HTTP methods
  // ══════════════════════════════════════════════════════════════════

  /// GET a single object.
  ///
  /// ```dart
  /// final r = await nio.get<User>('/users/1', fromJson: User.fromJson);
  /// ```
  Future<ApiResult<T>> get<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<T>('GET', path,
          fromJson: fromJson,
          queryParameters: queryParameters,
          options: options);

  /// GET a list of objects — saves you from writing the `List.map` boilerplate.
  ///
  /// ```dart
  /// final r = await nio.getList<User>('/users', fromJson: User.fromJson);
  /// ```
  Future<ApiResult<List<T>>> getList<T>(
    String path, {
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<List<T>>('GET', path,
          fromJson: (data) => (data as List)
              .map((e) => fromJson(e as Map<String, dynamic>))
              .toList(),
          queryParameters: queryParameters,
          options: options);

  /// POST.
  Future<ApiResult<T>> post<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<T>('POST', path,
          fromJson: fromJson,
          body: body,
          queryParameters: queryParameters,
          options: options);

  /// PUT.
  Future<ApiResult<T>> put<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<T>('PUT', path,
          fromJson: fromJson,
          body: body,
          queryParameters: queryParameters,
          options: options);

  /// PATCH.
  Future<ApiResult<T>> patch<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<T>('PATCH', path,
          fromJson: fromJson,
          body: body,
          queryParameters: queryParameters,
          options: options);

  /// DELETE.
  Future<ApiResult<T>> delete<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) =>
      _request<T>('DELETE', path,
          fromJson: fromJson,
          body: body,
          queryParameters: queryParameters,
          options: options);

  // ══════════════════════════════════════════════════════════════════
  // File transfer
  // ══════════════════════════════════════════════════════════════════

  /// Upload a file with optional progress tracking.
  ///
  /// ```dart
  /// final r = await nio.upload<UploadResponse>(
  ///   '/upload',
  ///   filePath: '/path/to/photo.jpg',
  ///   fromJson: UploadResponse.fromJson,
  ///   onProgress: (sent, total) => print('${sent / total * 100}%'),
  /// );
  /// ```
  Future<ApiResult<T>> upload<T>(
    String path, {
    required String filePath,
    String fileField = 'file',
    String? fileName,
    Map<String, dynamic>? extraFields,
    T Function(dynamic json)? fromJson,
    void Function(int sent, int total)? onProgress,
    NioOptions? options,
  }) async {
    final nioOpts = options ?? config.defaultOptions;

    try {
      final formData = FormData.fromMap({
        if (extraFields != null) ...extraFields,
        fileField:
            await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          headers: nioOpts.extraHeaders,
          extra: {nioOptionsKey: nioOpts},
        ),
        cancelToken: nioOpts.cancelToken,
      );

      return _parseResponse(response, fromJson);
    } on DioException catch (e) {
      return _handleDioError(e, nioOpts);
    } catch (e, st) {
      return _handleUnexpected(e, st, nioOpts);
    }
  }

  /// Download a file to [savePath]. Returns the path on success.
  ///
  /// ```dart
  /// final r = await nio.download(
  ///   '/files/report.pdf',
  ///   '/tmp/report.pdf',
  ///   onProgress: (received, total) => print('$received / $total'),
  /// );
  /// ```
  Future<ApiResult<String>> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    NioOptions? options,
  }) async {
    final nioOpts = options ?? config.defaultOptions;

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        options: Options(extra: {nioOptionsKey: nioOpts}),
        cancelToken: nioOpts.cancelToken,
      );
      return Success(savePath);
    } on DioException catch (e) {
      return _handleDioError(e, nioOpts);
    } catch (e, st) {
      return _handleUnexpected(e, st, nioOpts);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Mock helpers
  // ══════════════════════════════════════════════════════════════════

  /// Register a mock response (useful for testing & development).
  void mock(
    String path, {
    dynamic data,
    int statusCode = 200,
    String? method,
    Duration? delay,
  }) =>
      _mockInterceptor.mock(path,
          data: data,
          statusCode: statusCode,
          method: method,
          delay: delay);

  /// Remove all registered mocks.
  void clearMocks() => _mockInterceptor.clearMocks();

  // ══════════════════════════════════════════════════════════════════
  // Cache helpers
  // ══════════════════════════════════════════════════════════════════

  /// Clear the entire response cache.
  void clearCache() => _cacheInterceptor.clear();

  /// Remove cached entries whose key contains [path].
  void invalidateCache(String path) => _cacheInterceptor.invalidate(path);

  // ══════════════════════════════════════════════════════════════════
  // Offline queue
  // ══════════════════════════════════════════════════════════════════

  /// Pending requests (oldest first). Empty if [NioConfig.offlineQueue] is null.
  Future<List<PendingOfflineRequest>> peekOfflineQueue() async {
    final q = config.offlineQueue;
    if (q == null) return const [];
    final list = await q.storage.loadAll();
    list.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return List.unmodifiable(list);
  }

  /// Drop every stored offline request.
  Future<void> clearOfflineQueue() async {
    await config.offlineQueue?.storage.saveAll([]);
  }

  /// Replay queued requests in order against each item's saved [PendingOfflineRequest.apiBaseUrl].
  ///
  /// Call this when you know the device is online (e.g. after
  /// `Connectivity().onConnectivityChanged` fires, or on app resume).
  ///
  /// Mutating requests (`POST` / `PUT` / …) may run **more than once** if the server
  /// already applied them — design idempotent endpoints where possible.
  Future<OfflineFlushResult> flushOfflineQueue() async {
    final settings = config.offlineQueue;
    if (settings == null) return OfflineFlushResult.empty;

    var pending = await settings.storage.loadAll();
    pending.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));

    var succeeded = 0;
    var failed = 0;
    final stillPending = <PendingOfflineRequest>[];

    for (final item in pending) {
      final nioOpts = NioOptions(
        requiresAuth: item.requiresAuth,
        extraHeaders: item.extraHeaders,
        queueWhenOffline: false,
        showErrorMessage: false,
        maxRetries: 0,
      );

      final base = item.apiBaseUrl.isEmpty ? config.baseUrl : item.apiBaseUrl;

      try {
        final ro = RequestOptions(
          baseUrl: base,
          path: item.path,
          method: item.method,
          data: item.body,
          queryParameters: item.queryParameters,
          headers: item.extraHeaders == null ? {} : Map.from(item.extraHeaders!),
          sendTimeout: nioOpts.timeout,
          receiveTimeout: nioOpts.timeout,
          extra: {nioOptionsKey: nioOpts},
        );
        await _dio.fetch(ro);
        succeeded++;
      } on DioException {
        failed++;
        stillPending.add(item);
      } catch (_) {
        failed++;
        stillPending.add(item);
      }
    }

    await settings.storage.saveAll(stillPending);
    return OfflineFlushResult(
      succeeded: succeeded,
      failed: failed,
      remaining: stillPending.length,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // Internal
  // ══════════════════════════════════════════════════════════════════

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    T Function(dynamic json)? fromJson,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    NioOptions? options,
  }) async {
    final nioOpts = options ?? config.defaultOptions;

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: nioOpts.extraHeaders,
          sendTimeout: nioOpts.timeout,
          receiveTimeout: nioOpts.timeout,
          extra: {nioOptionsKey: nioOpts},
        ),
        cancelToken: nioOpts.cancelToken,
      );

      return _parseResponse(response, fromJson);
    } on DioException catch (e) {
      if (await _tryEnqueueOffline(
        e,
        method: method,
        path: path,
        body: body,
        queryParameters: queryParameters,
        nioOpts: nioOpts,
      )) {
        const queued = NioError(
          type: NioErrorType.queuedOffline,
          message: 'Request saved to offline queue',
        );
        _notifyError(queued, nioOpts);
        return const Failure(queued);
      }
      return _handleDioError(e, nioOpts);
    } catch (e, st) {
      return _handleUnexpected(e, st, nioOpts);
    }
  }

  ApiResult<T> _parseResponse<T>(
    Response response,
    T Function(dynamic json)? fromJson,
  ) {
    try {
      dynamic data = response.data;

      if (config.responseExtractor != null) {
        data = config.responseExtractor!(data);
      }

      final T parsed = fromJson != null ? fromJson(data) : data as T;
      return Success(parsed, statusCode: response.statusCode);
    } catch (e, st) {
      return Failure(NioError(
        type: NioErrorType.decode,
        message: 'Failed to decode response: $e',
        statusCode: response.statusCode,
        responseData: response.data,
        stackTrace: st,
      ));
    }
  }

  Failure<T> _handleDioError<T>(DioException e, NioOptions nioOpts) {
    final nioError = ErrorHandler.fromDioException(
      e,
      statusErrors: config.statusErrors,
    );
    _notifyError(nioError, nioOpts);
    return Failure(nioError);
  }

  Failure<T> _handleUnexpected<T>(
    Object e,
    StackTrace st,
    NioOptions nioOpts,
  ) {
    final nioError = NioError(
      type: NioErrorType.unknown,
      message: 'Unexpected error: $e',
      stackTrace: st,
    );
    _notifyError(nioError, nioOpts);
    return Failure(nioError);
  }

  void _notifyError(NioError error, NioOptions options) {
    config.onError?.call(error);
    if (options.showErrorMessage && config.showError != null) {
      config.showError!(error.userMessage);
    }
  }

  String _nextOfflineId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_offlineIdSeq++}';

  bool _canSerializeOfflineBody(dynamic body) {
    if (body == null) return true;
    if (body is FormData) return false;
    try {
      jsonEncode(body);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryEnqueueOffline(
    DioException e, {
    required String method,
    required String path,
    required dynamic body,
    required Map<String, dynamic>? queryParameters,
    required NioOptions nioOpts,
  }) async {
    final settings = config.offlineQueue;
    if (settings == null) return false;
    if (e.type != DioExceptionType.connectionError) return false;

    final wantQueue = nioOpts.queueWhenOffline || settings.defaultQueueWhenOffline;
    if (!wantQueue) return false;

    final m = method.toUpperCase();
    if (!settings.queueableMethods.contains(m)) return false;
    if (!_canSerializeOfflineBody(body)) return false;

    late List<PendingOfflineRequest> existing;
    try {
      existing = await settings.storage.loadAll();
    } catch (_) {
      return false;
    }
    if (existing.length >= settings.maxPending) return false;

    try {
      final req = PendingOfflineRequest(
        apiBaseUrl: config.baseUrl,
        id: _nextOfflineId(),
        method: m,
        path: path,
        queryParameters: queryParameters,
        body: body,
        extraHeaders: nioOpts.extraHeaders == null
            ? null
            : Map<String, dynamic>.from(nioOpts.extraHeaders!),
        requiresAuth: nioOpts.requiresAuth,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await settings.storage.saveAll([...existing, req]);
      settings.onRequestQueued?.call(req);
      return true;
    } catch (_) {
      return false;
    }
  }
}
