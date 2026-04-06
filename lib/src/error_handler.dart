import 'package:dio/dio.dart';

import 'nio_error.dart';

/// Maps [DioException] into a typed [NioError].
class ErrorHandler {
  ErrorHandler._();

  static NioError fromDioException(
    DioException error, {
    Map<int, NioError Function(dynamic responseData)>? statusErrors,
  }) {
    // Let custom status handlers take precedence.
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusErrors != null) {
      final handler = statusErrors[statusCode];
      if (handler != null) return handler(error.response?.data);
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NioError(
          type: NioErrorType.timeout,
          message: 'Request timed out: ${error.message}',
          statusCode: statusCode,
        ),
      DioExceptionType.cancel => NioError(
          type: NioErrorType.cancelled,
          message: 'Request cancelled',
          statusCode: statusCode,
        ),
      DioExceptionType.connectionError => NioError(
          type: NioErrorType.network,
          message: error.message ?? 'No internet connection',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse =>
        _fromStatusCode(error),
      _ => NioError(
          type: NioErrorType.unknown,
          message: error.message ?? 'Unknown error',
          statusCode: statusCode,
          responseData: error.response?.data,
        ),
    };
  }

  static NioError _fromStatusCode(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final serverMsg = _extractServerMessage(data);

    return switch (status) {
      400 => NioError(
          type: NioErrorType.badRequest,
          message: serverMsg ?? 'Bad request',
          statusCode: 400,
          responseData: data,
        ),
      401 => NioError(
          type: NioErrorType.unauthorized,
          message: serverMsg ?? 'Unauthorized',
          statusCode: 401,
          responseData: data,
        ),
      403 => NioError(
          type: NioErrorType.forbidden,
          message: serverMsg ?? 'Forbidden',
          statusCode: 403,
          responseData: data,
        ),
      404 => NioError(
          type: NioErrorType.notFound,
          message: serverMsg ?? 'Not found',
          statusCode: 404,
          responseData: data,
        ),
      final s? when s >= 500 => NioError(
          type: NioErrorType.server,
          message: serverMsg ?? 'Server error ($s)',
          statusCode: s,
          responseData: data,
        ),
      _ => NioError(
          type: NioErrorType.unknown,
          message: serverMsg ?? 'Unexpected status $status',
          statusCode: status,
          responseData: data,
        ),
    };
  }

  /// Best-effort extraction of a human-readable message from common
  /// response formats: `{"message": "..."}` or `{"error": "..."}`.
  static String? _extractServerMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['error'] as String?;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}
