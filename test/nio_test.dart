import 'package:nio/nio.dart';
import 'package:test/test.dart';

// ── Simple model for testing ──────────────────────────────────────

class _User {
  final int id;
  final String name;

  _User({required this.id, required this.name});

  factory _User.fromJson(Map<String, dynamic> json) =>
      _User(id: json['id'] as int, name: json['name'] as String);
}

void main() {
  late Nio nio;

  setUp(() {
    nio = Nio(config: const NioConfig(baseUrl: 'https://test.api'));
  });

  group('ApiResult', () {
    test('Success exposes data', () {
      const result = Success(42, statusCode: 200);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.errorOrNull, isNull);
      expect(result.dataOrThrow, 42);
    });

    test('Failure exposes error', () {
      const error = NioError(
        type: NioErrorType.network,
        message: 'offline',
      );
      const result = Failure<int>(error);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, error);
      expect(() => result.dataOrThrow, throwsA(isA<NioError>()));
    });

    test('when() dispatches correctly', () {
      const success = Success<String>('hello');
      final greeting = success.when(
        success: (data) => 'Got: $data',
        failure: (err) => 'Error',
      );
      expect(greeting, 'Got: hello');

      const failure = Failure<String>(
        NioError(type: NioErrorType.server, message: 'boom'),
      );
      final errMsg = failure.when(
        success: (data) => 'ok',
        failure: (err) => err.message,
      );
      expect(errMsg, 'boom');
    });

    test('map() transforms success, preserves failure', () {
      const success = Success<int>(5);
      final mapped = success.map((n) => n * 2);
      expect(mapped.dataOrNull, 10);

      const failure = Failure<int>(
        NioError(type: NioErrorType.unknown, message: 'err'),
      );
      final mappedFail = failure.map((n) => n * 2);
      expect(mappedFail.isFailure, isTrue);
    });
  });

  group('NioError', () {
    test('userMessage returns human-readable strings', () {
      const error = NioError(type: NioErrorType.network, message: 'test');
      expect(error.userMessage, contains('internet'));

      const timeout = NioError(type: NioErrorType.timeout, message: 'test');
      expect(timeout.userMessage, contains('timed out'));

      const auth = NioError(type: NioErrorType.unauthorized, message: 'test');
      expect(auth.userMessage, contains('log in'));
    });

    test('toString includes type and message', () {
      const error = NioError(
        type: NioErrorType.server,
        message: 'Internal error',
        statusCode: 500,
      );
      expect(error.toString(), contains('server'));
      expect(error.toString(), contains('500'));
    });
  });

  group('Mock support', () {
    test('mock returns canned response for GET', () async {
      nio.mock('/users/1', data: {'id': 1, 'name': 'Alice'});

      final result = await nio.get<_User>(
        '/users/1',
        fromJson: (json) => _User.fromJson(json as Map<String, dynamic>),
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.name, 'Alice');
    });

    test('mock returns canned response for list', () async {
      nio.mock('/users', data: [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);

      final result = await nio.getList<_User>(
        '/users',
        fromJson: _User.fromJson,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, 2);
      expect(result.dataOrNull?.first.name, 'Alice');
    });

    test('mock supports POST', () async {
      nio.mock('/users', method: 'POST', data: {'id': 3, 'name': 'Charlie'});

      final result = await nio.post<_User>(
        '/users',
        body: {'name': 'Charlie'},
        fromJson: (json) => _User.fromJson(json as Map<String, dynamic>),
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.name, 'Charlie');
    });

    test('clearMocks removes all mocks', () async {
      nio.mock('/users/1', data: {'id': 1, 'name': 'Alice'});
      nio.clearMocks();

      // Without mock and without a real server, this will fail with a
      // network / connection error.
      final result = await nio.get<_User>(
        '/users/1',
        fromJson: (json) => _User.fromJson(json as Map<String, dynamic>),
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('NioOptions', () {
    test('copyWith overrides specified fields', () {
      const original = NioOptions(requiresAuth: true, maxRetries: 3);
      final copy = original.copyWith(maxRetries: 1);

      expect(copy.requiresAuth, isTrue);
      expect(copy.maxRetries, 1);
    });

    test('defaults are sensible', () {
      const opts = NioOptions();
      expect(opts.requiresAuth, isFalse);
      expect(opts.maxRetries, 0);
      expect(opts.cache, isFalse);
      expect(opts.showErrorMessage, isTrue);
    });
  });
}
