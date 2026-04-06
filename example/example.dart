// ignore_for_file: avoid_print, unused_local_variable

// ---------------------------------------------------------------
//  Nio — Complete Usage Example
// ---------------------------------------------------------------
//
// This file shows every major feature of Nio so you can copy-paste
// the parts you need into your own project.
//
// Topics covered:
//   1. Setup (NioConfig)
//   2. GET  — single object & list
//   3. POST / PUT / PATCH / DELETE
//   4. Auth & token refresh
//   5. Retry & caching
//   6. File upload & download
//   7. Result handling patterns
//   8. Custom error handlers
//   9. Testing with mocks
// ---------------------------------------------------------------

import 'package:nio/nio.dart';

// ════════════════════════════════════════════════════════════════════
// STEP 1 — Create your model classes (normal Dart / Flutter models)
// ════════════════════════════════════════════════════════════════════

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  /// Standard fromJson factory — Nio calls this for you.
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class Post {
  final int id;
  final String title;

  Post({required this.id, required this.title});

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        title: json['title'] as String,
      );
}

// ════════════════════════════════════════════════════════════════════
// STEP 2 — Set up Nio (once, usually in main.dart or a DI container)
// ════════════════════════════════════════════════════════════════════

/// Simulated token storage (use SharedPreferences / secure storage in real apps).
String? _token = 'my-access-token';

Nio createNio() {
  return Nio(
    config: NioConfig(
      // ── Base URL ──────────────────────────────────────────────
      baseUrl: 'https://jsonplaceholder.typicode.com',

      // ── Timeouts ─────────────────────────────────────────────
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),

      // ── Global headers (sent with every request) ─────────────
      headers: {
        'X-App-Version': '1.0.0',
      },

      // ── Auth: provide your token ─────────────────────────────
      tokenProvider: () async => _token,

      // ── Auth: refresh logic (called automatically on 401) ────
      refreshToken: () async {
        // In a real app you would call your refresh-token endpoint
        // and save the new token.
        print('🔄 Refreshing token...');
        _token = 'new-refreshed-token';
      },

      // ── API response unwrapping ──────────────────────────────
      //
      // If your API wraps every response like:
      //   { "status": 200, "data": { ... }, "message": "OK" }
      //
      // Uncomment the line below so fromJson only sees the inner object:
      //
      // responseExtractor: (json) => json['data'],

      // ── Global error callback (logging / analytics) ──────────
      onError: (error) {
        print('❌ Global error: ${error.type} — ${error.message}');
      },

      // ── Optional UI callback (show Snackbar, toast, etc.) ────
      showError: (message) {
        print('🔔 Show to user: $message');
      },

      // ── Custom status code → error mapping ───────────────────
      statusErrors: {
        429: (data) => const NioError(
              type: NioErrorType.unknown,
              message: 'Too many requests — slow down!',
              statusCode: 429,
            ),
      },

      // ── Logging (only prints in debug mode) ──────────────────
      enableLogging: true,

      // ── Default options for every request ─────────────────────
      defaultOptions: const NioOptions(
        requiresAuth: true,
        showErrorMessage: true,
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
// STEP 3 — Use Nio to call APIs
// ════════════════════════════════════════════════════════════════════

Future<void> main() async {
  final nio = createNio();

  // ── GET single object ────────────────────────────────────────────
  print('\n=== GET single user ===');
  final userResult = await nio.get<User>(
    '/users/1',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
  );

  userResult.when(
    success: (user) => print('✅ Got user: ${user.name} (${user.email})'),
    failure: (err) => print('❌ Failed: ${err.userMessage}'),
  );

  // ── GET list of objects ──────────────────────────────────────────
  print('\n=== GET list of users ===');
  final usersResult = await nio.getList<User>(
    '/users',
    fromJson: User.fromJson,
  );

  usersResult.when(
    success: (users) => print('✅ Got ${users.length} users'),
    failure: (err) => print('❌ Failed: ${err.message}'),
  );

  // ── GET with query parameters ────────────────────────────────────
  print('\n=== GET with query params ===');
  final postsResult = await nio.getList<Post>(
    '/posts',
    fromJson: Post.fromJson,
    queryParameters: {'userId': 1},
  );

  postsResult.when(
    success: (posts) => print('✅ User 1 has ${posts.length} posts'),
    failure: (err) => print('❌ ${err.message}'),
  );

  // ── POST — create a resource ─────────────────────────────────────
  print('\n=== POST create post ===');
  final createResult = await nio.post<Post>(
    '/posts',
    body: {'title': 'Hello from Nio', 'body': 'This is easy!', 'userId': 1},
    fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
  );

  createResult.when(
    success: (post) => print('✅ Created post #${post.id}: ${post.title}'),
    failure: (err) => print('❌ ${err.message}'),
  );

  // ── PUT — update a resource ──────────────────────────────────────
  print('\n=== PUT update post ===');
  final updateResult = await nio.put<Post>(
    '/posts/1',
    body: {'id': 1, 'title': 'Updated title', 'body': 'Updated', 'userId': 1},
    fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
  );

  updateResult.when(
    success: (post) => print('✅ Updated: ${post.title}'),
    failure: (err) => print('❌ ${err.message}'),
  );

  // ── DELETE ────────────────────────────────────────────────────────
  print('\n=== DELETE post ===');
  final deleteResult = await nio.delete('/posts/1');

  if (deleteResult.isSuccess) {
    print('✅ Deleted successfully');
  }

  // ── With retry (retries up to 2 times on network/5xx errors) ─────
  print('\n=== GET with retry ===');
  final retryResult = await nio.get<User>(
    '/users/1',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
    options: const NioOptions(
      requiresAuth: true,
      maxRetries: 2,
    ),
  );

  print('Retry result: ${retryResult.isSuccess ? "success" : "failed"}');

  // ── With caching ─────────────────────────────────────────────────
  print('\n=== GET with caching ===');
  final cachedResult = await nio.get<User>(
    '/users/1',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
    options: const NioOptions(
      cache: true,
      cacheTtl: Duration(minutes: 10),
    ),
  );

  // Second call will be served from cache (no network request).
  final cachedAgain = await nio.get<User>(
    '/users/1',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
    options: const NioOptions(cache: true),
  );

  print('Cached result: ${cachedAgain.isSuccess ? "from cache!" : "failed"}');

  // ── Without auth (public endpoint) ───────────────────────────────
  print('\n=== Public endpoint (no auth) ===');
  final publicResult = await nio.get(
    '/posts/1',
    options: const NioOptions(requiresAuth: false),
  );

  print('Public result: ${publicResult.isSuccess}');

  // ── Cancel a request ─────────────────────────────────────────────
  print('\n=== Cancel request ===');
  final cancelToken = CancelToken();
  final cancelFuture = nio.get<User>(
    '/users/1',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
    options: NioOptions(cancelToken: cancelToken),
  );
  cancelToken.cancel('User navigated away');
  final cancelResult = await cancelFuture;

  cancelResult.when(
    success: (_) => print('Got data'),
    failure: (err) => print('Cancelled: ${err.type}'),
  );

  // ── Advanced result handling ─────────────────────────────────────
  print('\n=== Advanced result patterns ===');

  // dataOrNull — returns null on failure
  final name = userResult.dataOrNull?.name;
  print('Name (nullable): $name');

  // dataOrThrow — throws NioError on failure
  try {
    final user = userResult.dataOrThrow;
    print('Name (throws): ${user.name}');
  } on NioError catch (e) {
    print('Error: ${e.userMessage}');
  }

  // map — transform the success data
  final nameResult = userResult.map((user) => user.name);
  print('Mapped: ${nameResult.dataOrNull}');

  // maybeWhen — handle only what you care about
  userResult.maybeWhen(
    success: (user) => print('Got ${user.name}'),
    orElse: () => print('Something else happened'),
  );

  // ── Testing with mocks ──────────────────────────────────────────
  print('\n=== Mock support ===');

  nio.mock('/test/user', data: {'id': 99, 'name': 'Mock User', 'email': 'mock@test.com'});

  final mockResult = await nio.get<User>(
    '/test/user',
    fromJson: (json) => User.fromJson(json as Map<String, dynamic>),
  );

  mockResult.when(
    success: (user) => print('✅ Mock user: ${user.name}'),
    failure: (err) => print('❌ ${err.message}'),
  );

  nio.clearMocks();

  print('\n🎉 All examples completed!');
}
