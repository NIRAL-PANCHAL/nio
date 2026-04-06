import 'dart:math';

import 'package:dio/dio.dart';

import '../nio_options.dart';

/// Retries failed requests with exponential backoff.
///
/// Only retries **network errors**, **timeouts**, and **5xx** responses.
/// 4xx errors (including 401/403) are never retried here — the
/// [AuthInterceptor] handles those.
class RetryInterceptor extends Interceptor {
  final Dio _dio;

  RetryInterceptor({required Dio dio}) : _dio = dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final nioOpts =
        err.requestOptions.extra[nioOptionsKey] as NioOptions?;
    final maxRetries = nioOpts?.maxRetries ?? 0;
    final attempt =
        (err.requestOptions.extra[retryCountKey] as int?) ?? 0;

    if (attempt < maxRetries && _shouldRetry(err)) {
      final baseDelay = nioOpts?.retryDelay ?? const Duration(milliseconds: 500);
      final delay = baseDelay * pow(2, attempt);
      await Future<void>.delayed(delay);

      err.requestOptions.extra[retryCountKey] = attempt + 1;

      try {
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      } catch (_) {
        // Fall through to forward original error.
      }
    }

    handler.next(err);
  }

  static bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.cancel) return false;

    // Retry server errors (5xx).
    final status = err.response?.statusCode;
    if (status != null && status >= 500) return true;

    // Retry network / timeout errors.
    return const {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    }.contains(err.type);
  }
}
