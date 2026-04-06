import 'nio_error.dart';
import 'nio_options.dart';

/// Callback that returns the current auth token (or null).
typedef TokenProvider = Future<String?> Function();

/// Callback that refreshes the token and persists it.
/// After this completes, [TokenProvider] should return the new token.
typedef TokenRefresher = Future<void> Function();

/// Extracts the "payload" from a wrapped API response.
///
/// Example: if your server always returns `{"data": ..., "message": "..."}`,
/// pass `(json) => json['data']` so `fromJson` only sees the inner object.
typedef DataExtractor = dynamic Function(dynamic responseData);

/// Global configuration — create once and pass to [Nio].
class NioConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, dynamic> headers;

  /// Return the current bearer token. Called before every authenticated request.
  final TokenProvider? tokenProvider;

  /// Called when a 401 is received. Refresh & persist your token here.
  final TokenRefresher? refreshToken;

  /// Global error callback (logging, analytics, etc.).
  final void Function(NioError error)? onError;

  /// Optional UI callback — e.g. show a Snackbar.
  final void Function(String message)? showError;

  /// Unwrap server response envelopes before `fromJson` receives data.
  final DataExtractor? responseExtractor;

  /// Print request/response/error logs (only in debug mode).
  final bool enableLogging;

  /// Map specific HTTP status codes to custom [NioError]s.
  final Map<int, NioError Function(dynamic responseData)>? statusErrors;

  /// Defaults applied to every request unless overridden per-call.
  final NioOptions defaultOptions;

  const NioConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.headers = const {},
    this.tokenProvider,
    this.refreshToken,
    this.onError,
    this.showError,
    this.responseExtractor,
    this.enableLogging = false,
    this.statusErrors,
    this.defaultOptions = const NioOptions(),
  });
}
