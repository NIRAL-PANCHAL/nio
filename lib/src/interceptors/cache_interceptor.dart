import 'package:dio/dio.dart';

import '../nio_options.dart';

/// Simple in-memory cache for GET requests.
///
/// Respects [NioOptions.cache] and [NioOptions.cacheTtl].
/// Call [clear] or [invalidate] to remove entries manually.
class CacheInterceptor extends Interceptor {
  final Map<String, _CacheEntry> _store = {};

  // ── Request: return cached response if available ──────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final nioOpts = options.extra[nioOptionsKey] as NioOptions?;
    final shouldCache = nioOpts?.cache ?? false;

    if (shouldCache && options.method.toUpperCase() == 'GET') {
      final key = _keyFor(options);
      final entry = _store[key];
      if (entry != null && !entry.isExpired) {
        return handler.resolve(
          Response(
            requestOptions: options,
            data: entry.data,
            statusCode: entry.statusCode,
          ),
        );
      }
    }

    handler.next(options);
  }

  // ── Response: store in cache ──────────────────────────────────────

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final nioOpts =
        response.requestOptions.extra[nioOptionsKey] as NioOptions?;
    final shouldCache = nioOpts?.cache ?? false;

    if (shouldCache &&
        response.requestOptions.method.toUpperCase() == 'GET') {
      final ttl = nioOpts?.cacheTtl ?? const Duration(minutes: 5);
      _store[_keyFor(response.requestOptions)] = _CacheEntry(
        data: response.data,
        statusCode: response.statusCode,
        expiry: DateTime.now().add(ttl),
      );
    }

    handler.next(response);
  }

  // ── Public helpers ────────────────────────────────────────────────

  /// Remove all cached entries.
  void clear() => _store.clear();

  /// Remove a single cached path (e.g. after a mutation).
  void invalidate(String path) {
    _store.removeWhere((key, _) => key.contains(path));
  }

  static String _keyFor(RequestOptions options) => options.uri.toString();
}

class _CacheEntry {
  final dynamic data;
  final int? statusCode;
  final DateTime expiry;

  _CacheEntry({
    required this.data,
    required this.statusCode,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);
}
