import 'nio_error.dart';

/// The single return type for every Nio call.
///
/// Pattern-match with [when] / [maybeWhen], or use helpers like
/// [dataOrNull], [errorOrNull], [dataOrThrow].
///
/// ```dart
/// final result = await nio.get<User>('/me', fromJson: User.fromJson);
///
/// result.when(
///   success: (user) => print(user.name),
///   failure: (error) => print(error.userMessage),
/// );
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Returns [T] on success, `null` on failure.
  T? get dataOrNull => switch (this) {
        final Success<T> s => s.data,
        Failure<T>() => null,
      };

  /// Returns [NioError] on failure, `null` on success.
  NioError? get errorOrNull => switch (this) {
        Success<T>() => null,
        final Failure<T> f => f.error,
      };

  /// Returns [T] on success, **throws** [NioError] on failure.
  T get dataOrThrow => switch (this) {
        final Success<T> s => s.data,
        final Failure<T> f => throw f.error,
      };

  /// Exhaustive callback handler — both branches are required.
  R when<R>({
    required R Function(T data) success,
    required R Function(NioError error) failure,
  }) =>
      switch (this) {
        final Success<T> s => success(s.data),
        final Failure<T> f => failure(f.error),
      };

  /// Non-exhaustive callback handler with a fallback.
  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(NioError error)? failure,
    required R Function() orElse,
  }) =>
      switch (this) {
        final Success<T> s =>
          success != null ? success(s.data) : orElse(),
        final Failure<T> f =>
          failure != null ? failure(f.error) : orElse(),
      };

  /// Transform the success data without touching the failure branch.
  ApiResult<R> map<R>(R Function(T data) transform) => switch (this) {
        final Success<T> s =>
          Success(transform(s.data), statusCode: s.statusCode),
        final Failure<T> f => Failure(f.error),
      };

  /// Async version of [map].
  Future<ApiResult<R>> asyncMap<R>(
    Future<R> Function(T data) transform,
  ) async =>
      switch (this) {
        final Success<T> s =>
          Success(await transform(s.data), statusCode: s.statusCode),
        final Failure<T> f => Failure<R>(f.error),
      };
}

/// A successful API result carrying [data].
final class Success<T> extends ApiResult<T> {
  final T data;
  final int? statusCode;

  const Success(this.data, {this.statusCode});

  @override
  String toString() => 'Success($statusCode, data: $data)';
}

/// A failed API result carrying a [NioError].
final class Failure<T> extends ApiResult<T> {
  final NioError error;

  const Failure(this.error);

  @override
  String toString() => 'Failure(${error.type}, ${error.message})';
}
