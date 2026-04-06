# Nio

A powerful, developer-friendly networking layer built on top of [Dio](https://pub.dev/packages/dio).

Nio eliminates boilerplate, centralizes API handling, and gives you a scalable, production-ready architecture for Flutter (and Dart) apps.

## Why Nio?

Working directly with Dio means repeating the same patterns in every project — try/catch blocks, status code checks, token management, error mapping.
Nio handles all of that so you can focus on your app.

| Feature | Raw Dio | Nio |
|---|---|---|
| Typed results | Manual `try/catch` + casting | `ApiResult<T>` with `when()` |
| Auth token handling | Copy-paste interceptor | Built-in, one config line |
| Token refresh on 401 | DIY, easy to get wrong | Automatic single-flight refresh |
| Retry with backoff | Add extra package | `maxRetries: 2` per request |
| Caching | Not included | `cache: true` per request |
| Error types | One `DioException` catch-all | `NioErrorType` enum (network, timeout, unauthorized, ...) |
| List parsing | `.map().toList()` every time | `getList<User>(...)` |
| Testing | Mock the whole Dio | `nio.mock('/path', data: ...)` |

---

## Installation

Add Nio to your `pubspec.yaml`:

```yaml
dependencies:
  nio: ^0.0.1
```

Then run:

```bash
dart pub get
```

---

## Quick Start (2 minutes)

### 1. Create a Nio instance

```dart
import 'package:nio/nio.dart';

// Create once — reuse everywhere.
final nio = Nio(
  config: NioConfig(
    baseUrl: 'https://api.example.com',
  ),
);
```

### 2. Make an API call

```dart
// GET a single user
final result = await nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
);
```

### 3. Handle the result

```dart
result.when(
  success: (user) => print(user.name),    // User object
  failure: (error) => print(error.userMessage), // Human-readable message
);
```

**That's it.** No try/catch. No status code checks. No boilerplate.

---

## Full Setup

Here is a complete `NioConfig` showing every option:

```dart
final nio = Nio(
  config: NioConfig(
    // Required
    baseUrl: 'https://api.example.com/v1',

    // Timeouts (default: 30 seconds each)
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 15),
    sendTimeout: Duration(seconds: 15),

    // Global headers sent with every request
    headers: {
      'X-App-Version': '2.0.0',
      'X-Platform': 'android',
    },

    // Auth: return your stored token
    tokenProvider: () async => await storage.getToken(),

    // Auth: refresh when a 401 is received
    refreshToken: () async {
      final newToken = await authService.refresh();
      await storage.saveToken(newToken);
    },

    // Unwrap server response envelopes automatically
    // e.g. { "data": { ... }, "message": "OK" } → fromJson gets { ... }
    responseExtractor: (json) => json['data'],

    // Global error callback (for logging, analytics, Crashlytics, etc.)
    onError: (error) => logger.e('API Error: ${error.message}'),

    // Optional UI callback (e.g. show a Snackbar)
    showError: (message) => showSnackBar(message),

    // Custom status code → error mapping
    statusErrors: {
      429: (data) => NioError(
            type: NioErrorType.unknown,
            message: 'Rate limited — please slow down',
            statusCode: 429,
          ),
    },

    // Print request/response logs in debug mode
    enableLogging: true,

    // Default options applied to every request
    defaultOptions: NioOptions(
      requiresAuth: true,     // all requests send token by default
      showErrorMessage: true,  // trigger showError callback on failure
    ),
  ),
);
```

---

## Making API Calls

### GET — single object

```dart
final result = await nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
);
```

### GET — list of objects

```dart
// No more .map().toList() boilerplate!
final result = await nio.getList<User>(
  '/users',
  fromJson: User.fromJson,
);
```

### GET — with query parameters

```dart
final result = await nio.getList<Post>(
  '/posts',
  fromJson: Post.fromJson,
  queryParameters: {'userId': 1, 'page': 2},
);
```

### POST

```dart
final result = await nio.post<User>(
  '/users',
  body: {'name': 'John', 'email': 'john@example.com'},
  fromJson: (json) => User.fromJson(json),
);
```

### PUT / PATCH / DELETE

```dart
// PUT — replace the resource
final result = await nio.put<User>(
  '/users/1',
  body: user.toJson(),
  fromJson: (json) => User.fromJson(json),
);

// PATCH — partial update
final result = await nio.patch<User>(
  '/users/1',
  body: {'name': 'New Name'},
  fromJson: (json) => User.fromJson(json),
);

// DELETE
final result = await nio.delete('/users/1');
```

### GET — raw response (no model parsing)

```dart
// When you don't need a model, skip fromJson.
// T defaults to dynamic — you get the raw JSON.
final result = await nio.get('/config');
final value = result.dataOrNull['feature_flag']; // dynamic access
```

---

## Handling Results

Every Nio call returns `ApiResult<T>` — a sealed class with two variants: `Success<T>` and `Failure<T>`.

### Pattern matching (recommended)

```dart
result.when(
  success: (user) => setState(() => _user = user),
  failure: (error) => showSnackBar(error.userMessage),
);
```

### Nullable access

```dart
final user = result.dataOrNull;   // User? — null if failure
final error = result.errorOrNull;  // NioError? — null if success
```

### Throw on failure

```dart
try {
  final user = result.dataOrThrow;  // User — throws NioError if failure
} on NioError catch (e) {
  print(e.userMessage);
}
```

### Check status

```dart
if (result.isSuccess) { ... }
if (result.isFailure) { ... }
```

### Transform data

```dart
// map: transform success data, pass through failure
final nameResult = result.map((user) => user.name);  // ApiResult<String>
```

### Partial matching

```dart
result.maybeWhen(
  success: (user) => print(user.name),
  orElse: () => print('Did not succeed'),
);
```

### Dart 3 pattern matching

```dart
switch (result) {
  case Success(data: final user):
    print(user.name);
  case Failure(error: final err):
    print(err.userMessage);
}
```

---

## Per-Request Options

Override global defaults for any individual call:

```dart
final result = await nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
  options: NioOptions(
    requiresAuth: true,          // attach bearer token
    maxRetries: 3,                // retry on network / 5xx errors
    retryDelay: Duration(seconds: 1), // base delay (doubles each attempt)
    cache: true,                  // serve from / store to memory cache
    cacheTtl: Duration(minutes: 10),  // cache lifetime
    showErrorMessage: false,      // suppress UI error callback
    timeout: Duration(seconds: 5), // override global timeout
    extraHeaders: {'X-Custom': 'value'}, // per-request headers
    cancelToken: myCancelToken,   // cancel this request
  ),
);
```

---

## Authentication

### Setup

```dart
NioConfig(
  tokenProvider: () async => await secureStorage.read(key: 'token'),
  refreshToken: () async {
    final response = await authApi.refreshToken();
    await secureStorage.write(key: 'token', value: response.newToken);
  },
  defaultOptions: NioOptions(requiresAuth: true),
)
```

### How it works

1. Before every request where `requiresAuth = true`, Nio calls `tokenProvider()` and adds `Authorization: Bearer <token>` to the request headers.
2. If the server returns **401 Unauthorized**, Nio automatically calls `refreshToken()`, then **retries the original request** with the new token.
3. If the retry also fails, the error is forwarded to your `onError` callback and returned as a `Failure`.
4. A guard prevents infinite refresh loops — each request is retried at most once.

### Public endpoints

```dart
// Skip auth for a specific request
nio.get('/public/config', options: NioOptions(requiresAuth: false));
```

---

## Retry

```dart
nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
  options: NioOptions(maxRetries: 3),
);
```

- Retries on **network errors**, **timeouts**, and **5xx** server errors.
- Does **not** retry **4xx** errors (those are app-level problems, not transient).
- Uses **exponential backoff**: 500ms → 1s → 2s → 4s ...
- Customize the base delay: `retryDelay: Duration(seconds: 1)`.

---

## Caching

```dart
nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
  options: NioOptions(cache: true, cacheTtl: Duration(minutes: 10)),
);
```

- Only **GET** requests are cached.
- Cache key = full URL (including query parameters).
- Expired entries are ignored and re-fetched.
- Clear everything: `nio.clearCache()`
- Invalidate a specific path: `nio.invalidateCache('/users')`

---

## File Upload

```dart
final result = await nio.upload<UploadResponse>(
  '/upload/avatar',
  filePath: '/path/to/photo.jpg',
  fileField: 'avatar',               // form field name (default: 'file')
  fileName: 'my_photo.jpg',           // optional override
  extraFields: {'userId': '123'},     // extra form fields
  fromJson: (json) => UploadResponse.fromJson(json),
  onProgress: (sent, total) {
    final percent = (sent / total * 100).toStringAsFixed(0);
    print('Uploading: $percent%');
  },
);
```

## File Download

```dart
final result = await nio.download(
  '/files/report.pdf',
  '/storage/downloads/report.pdf',
  onProgress: (received, total) {
    final percent = (received / total * 100).toStringAsFixed(0);
    print('Downloading: $percent%');
  },
);

result.when(
  success: (path) => print('Saved to $path'),
  failure: (err) => print('Download failed: ${err.message}'),
);
```

---

## Error Types

Every failure contains a `NioError` with a typed `NioErrorType`:

| Type | When | `userMessage` |
|---|---|---|
| `network` | No internet / DNS failure | "No internet connection..." |
| `timeout` | Connect / send / receive timeout | "Request timed out..." |
| `cancelled` | `CancelToken.cancel()` called | "Request was cancelled." |
| `unauthorized` | HTTP 401 | "Session expired..." |
| `forbidden` | HTTP 403 | "You don't have permission..." |
| `notFound` | HTTP 404 | "The requested resource was not found." |
| `badRequest` | HTTP 400 | "Invalid request..." |
| `server` | HTTP 5xx | "Server error..." |
| `decode` | JSON parse / cast failed | "Failed to process server response." |
| `unknown` | Anything else | "Something went wrong..." |

### Programmatic error handling

```dart
result.when(
  success: (data) => handleData(data),
  failure: (error) {
    switch (error.type) {
      case NioErrorType.unauthorized:
        navigateToLogin();
      case NioErrorType.network:
        showOfflineBanner();
      default:
        showSnackBar(error.userMessage);
    }
  },
);
```

---

## Logging

Enable in config:

```dart
NioConfig(enableLogging: true)
```

Logs request, response, and error details with a readable format:

```
[Nio] ┌── REQUEST ──────────────────────────────
[Nio] │ GET  https://api.example.com/users/1
[Nio] │ Headers: {Authorization: ••••••, Content-Type: application/json}
[Nio] └─────────────────────────────────────────
[Nio] ┌── RESPONSE ─────────────────────────────
[Nio] │ 200  GET  https://api.example.com/users/1
[Nio] │ Data: {id: 1, name: John, email: john@example.com}
[Nio] └─────────────────────────────────────────
```

- `Authorization` headers are **automatically redacted**.
- Logs are **only printed in debug mode** (stripped in release builds).

---

## Testing with Mocks

No real server needed — register mock responses and test your logic:

```dart
// Setup
final nio = Nio(config: NioConfig(baseUrl: 'https://api.test'));

// Register mock
nio.mock('/users/1', data: {'id': 1, 'name': 'Alice', 'email': 'a@test.com'});

// Call as normal — the mock interceptor returns canned data
final result = await nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
);

expect(result.isSuccess, true);
expect(result.dataOrNull?.name, 'Alice');

// Clean up
nio.clearMocks();
```

### Mock a specific HTTP method

```dart
nio.mock('/users', method: 'POST', data: {'id': 2, 'name': 'Bob'});
```

### Simulate network delay

```dart
nio.mock('/slow', data: {'ok': true}, delay: Duration(seconds: 2));
```

---

## Cancel a Request

```dart
final cancelToken = CancelToken();

// Start the request
final future = nio.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
  options: NioOptions(cancelToken: cancelToken),
);

// Cancel it (e.g. user navigated away)
cancelToken.cancel('User left the screen');

// The result will be Failure with NioErrorType.cancelled
final result = await future;
```

---

## Escape Hatch — Access Dio Directly

For anything Nio doesn't cover, you have full access to the underlying Dio instance:

```dart
// Get the raw Dio instance
final dio = nio.dio;

// Use it directly
final response = await dio.get('/some/endpoint',
  options: Options(responseType: ResponseType.bytes),
);
```

---

## Architecture

```
lib/
├── nio.dart                          ← Public API (import this)
└── src/
    ├── nio_client.dart               ← Nio class (main entry point)
    ├── nio_config.dart               ← Global configuration
    ├── nio_options.dart              ← Per-request options
    ├── api_result.dart               ← ApiResult<T> sealed class
    ├── nio_error.dart                ← NioError + NioErrorType
    ├── error_handler.dart            ← DioException → NioError mapping
    ├── nio_mock.dart                 ← Mock interceptor for testing
    └── interceptors/
        ├── auth_interceptor.dart     ← Token attach + 401 refresh
        ├── retry_interceptor.dart    ← Exponential backoff retry
        ├── logging_interceptor.dart  ← Debug-only request/response logs
        └── cache_interceptor.dart    ← In-memory GET cache
```

---

## Comparison: Raw Dio vs Nio

### Raw Dio (typical pattern)

```dart
try {
  final response = await dio.get('/users',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  if (response.statusCode == 200) {
    final users = (response.data as List)
        .map((e) => User.fromJson(e))
        .toList();
    setState(() => _users = users);
  }
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    // refresh token? retry? navigate to login?
  } else if (e.type == DioExceptionType.connectionTimeout) {
    showSnackBar('Timeout');
  } else {
    showSnackBar('Something went wrong');
  }
}
```

### Nio (same thing)

```dart
final result = await nio.getList<User>('/users', fromJson: User.fromJson);

result.when(
  success: (users) => setState(() => _users = users),
  failure: (err) => showSnackBar(err.userMessage),
);
```

Auth, retry, timeout handling, and error mapping are all handled by the config you wrote once.

---

## License

MIT
