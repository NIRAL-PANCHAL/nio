/// All possible error categories Nio can produce.
enum NioErrorType {
  network,
  timeout,
  cancelled,
  unauthorized,
  forbidden,
  notFound,
  badRequest,
  server,
  decode,
  unknown,
}

/// A structured error returned inside [Failure].
///
/// Use [type] for programmatic branching and [userMessage] for UI display.
class NioError implements Exception {
  final NioErrorType type;
  final String message;
  final int? statusCode;
  final dynamic responseData;
  final StackTrace? stackTrace;

  const NioError({
    required this.type,
    required this.message,
    this.statusCode,
    this.responseData,
    this.stackTrace,
  });

  /// Human-readable message safe to show in a Snackbar / dialog.
  String get userMessage => switch (type) {
        NioErrorType.network =>
          'No internet connection. Please check your network.',
        NioErrorType.timeout => 'Request timed out. Please try again.',
        NioErrorType.cancelled => 'Request was cancelled.',
        NioErrorType.unauthorized =>
          'Session expired. Please log in again.',
        NioErrorType.forbidden =>
          "You don't have permission to access this.",
        NioErrorType.notFound =>
          'The requested resource was not found.',
        NioErrorType.badRequest =>
          'Invalid request. Please check your input.',
        NioErrorType.server => 'Server error. Please try again later.',
        NioErrorType.decode => 'Failed to process server response.',
        NioErrorType.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'NioError($type): $message [status: $statusCode]';
}
