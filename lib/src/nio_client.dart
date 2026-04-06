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
}
