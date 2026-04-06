import 'package:dio/dio.dart';

/// Register canned responses so you can test without a real server.
///
/// ```dart
/// nio.mock('/users', data: [{'id': 1, 'name': 'John'}]);
/// final result = await nio.getList<User>('/users', fromJson: User.fromJson);
/// ```
class NioMockInterceptor extends Interceptor {
  final Map<String, _MockEntry> _mocks = {};

  /// Register a mock response for [path].
  ///
  /// * [method] — HTTP verb to match (case-insensitive). `null` matches any.
  /// * [delay] — simulate network latency.
  void mock(
    String path, {
    dynamic data,
    int statusCode = 200,
    String? method,
    Duration? delay,
  }) {
    final key = _key(method, path);
    _mocks[key] = _MockEntry(
      data: data,
      statusCode: statusCode,
      delay: delay,
    );
  }

  /// Remove a single mock.
  void removeMock(String path, {String? method}) {
    _mocks.remove(_key(method, path));
  }

  /// Remove all mocks.
  void clearMocks() => _mocks.clear();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Try exact method match first, then wildcard.
    final entry = _mocks[_key(options.method, options.path)] ??
        _mocks[_key(null, options.path)];

    if (entry != null) {
      if (entry.delay != null) await Future<void>.delayed(entry.delay!);
      return handler.resolve(
        Response(
          requestOptions: options,
          data: entry.data,
          statusCode: entry.statusCode,
        ),
      );
    }

    handler.next(options);
  }

  static String _key(String? method, String path) =>
      '${method?.toUpperCase() ?? '*'}:$path';
}

class _MockEntry {
  final dynamic data;
  final int statusCode;
  final Duration? delay;

  _MockEntry({required this.data, required this.statusCode, this.delay});
}
