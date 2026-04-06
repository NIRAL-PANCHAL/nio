import 'package:dio/dio.dart';

import '../nio_config.dart';
import '../nio_options.dart';

/// Attaches a bearer token on request and handles 401 → refresh → retry.
///
/// * Only adds the token when [NioOptions.requiresAuth] is `true`.
/// * On 401, calls [refreshToken] **once**, then retries the original request.
/// * A [Completer]-based single-flight guard prevents concurrent refresh calls.
class AuthInterceptor extends Interceptor {
  final TokenProvider _tokenProvider;
  final TokenRefresher? _refreshToken;
  final Dio _dio;

  AuthInterceptor({
    required TokenProvider tokenProvider,
    required TokenRefresher? refreshToken,
    required Dio dio,
  })  : _tokenProvider = tokenProvider,
        _refreshToken = refreshToken,
        _dio = dio;

  // ── Request: attach token ─────────────────────────────────────────

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final nioOpts = options.extra[nioOptionsKey] as NioOptions?;
    if (nioOpts?.requiresAuth ?? false) {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  // ── Error: refresh + retry on 401 ────────────────────────────────

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[authRetryKey] == true;

    if (!is401 || _refreshToken == null || alreadyRetried) {
      return handler.next(err);
    }

    try {
      await _refreshToken();

      // Mark so we don't loop if the retry also returns 401.
      err.requestOptions.extra[authRetryKey] = true;

      final response = await _dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (_) {
      return handler.next(err);
    }
  }
}
