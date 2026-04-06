import 'package:dio/dio.dart';

/// Pretty-prints request / response / error info.
///
/// Logs are only emitted in **debug mode** (when assertions are enabled).
/// Authorization headers are automatically redacted.
class NioLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('┌── REQUEST ──────────────────────────────');
    _log('│ ${options.method}  ${options.uri}');
    if (options.headers.isNotEmpty) {
      _log('│ Headers: ${_redact(options.headers)}');
    }
    if (options.data != null) {
      _log('│ Body: ${options.data}');
    }
    _log('└─────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('┌── RESPONSE ─────────────────────────────');
    _log('│ ${response.statusCode}  '
        '${response.requestOptions.method}  '
        '${response.requestOptions.uri}');
    _log('│ Data: ${response.data}');
    _log('└─────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log('┌── ERROR ────────────────────────────────');
    _log('│ ${err.type}  '
        '${err.requestOptions.method}  '
        '${err.requestOptions.uri}');
    if (err.response != null) {
      _log('│ Status: ${err.response?.statusCode}');
      _log('│ Data:   ${err.response?.data}');
    } else {
      _log('│ Message: ${err.message}');
    }
    _log('└─────────────────────────────────────────');
    handler.next(err);
  }

  // Only prints when assertions are enabled (debug mode).
  static void _log(String msg) {
    assert(() {
      print('[Nio] $msg');
      return true;
    }());
  }

  static Map<String, dynamic> _redact(Map<String, dynamic> headers) {
    return headers.map((k, v) {
      if (k.toLowerCase() == 'authorization') return MapEntry(k, '••••••');
      return MapEntry(k, v);
    });
  }
}
