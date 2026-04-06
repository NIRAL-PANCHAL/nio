## 0.0.2

- Fix pub.dev scoring: point `homepage` / `repository` at the real GitHub repo
  under [NIRAL-PANCHAL/nio](https://github.com/NIRAL-PANCHAL/nio)
- Add `issue_tracker` URL

## 0.0.1

- Initial release
- `Nio` client with GET, POST, PUT, PATCH, DELETE
- `getList<T>` for automatic list parsing
- `ApiResult<T>` sealed class with `Success` / `Failure`
- `NioError` with typed `NioErrorType` and human-readable `userMessage`
- Auth interceptor: auto token attach + 401 refresh + retry
- Retry interceptor: exponential backoff for network / 5xx errors
- Cache interceptor: in-memory GET caching with TTL
- Logging interceptor: debug-only, auto-redacted auth headers
- Mock support for testing without a server
- File upload with progress tracking
- File download with progress tracking
- `responseExtractor` for unwrapping server response envelopes
- Per-request `NioOptions` with global defaults via `NioConfig`
