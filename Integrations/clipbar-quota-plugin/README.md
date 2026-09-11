# AccessDeck CLIProxyAPI quota plugin

This directory contains a standalone Go dynamic-library plugin for
[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI). It collects the
quota windows displayed by AccessDeck for Codex, Claude, Gemini CLI,
Antigravity, Kimi, and xAI/Grok accounts.

The plugin is intentionally self-contained: the Go module uses only the
standard library and speaks CPA's version 1 C ABI and schema version 3 JSON
protocol directly. It does not read CPA's auth directory, open a second
network client, or persist credentials.

## Protocol and route boundaries

The plugin advertises only the `management_api` capability.

### Authenticated Management API routes

CPA mounts the declared routes below under its management prefix:

| Method | CPA route | Behavior |
| --- | --- | --- |
| `GET` | `/v0/management/plugins/clipbar-quota/snapshot` | Return the last in-memory snapshot. This does not contact providers. |
| `POST` | `/v0/management/plugins/clipbar-quota/refresh` | Refresh all supported auth entries and return the resulting snapshot. |

These routes remain behind CPA's normal Management API authentication. The
plugin does not accept, store, or document a management key. A caller must
authenticate to CPA itself; the plugin only receives the already-authorized
management request from the host.

### Browser resource route

The registration also declares a read-only resource at `/status`. CPA exposes
it without management authentication at:

```text
/v0/resource/plugins/clipbar-quota/status
```

The resource renders the cached snapshot as escaped HTML. It never refreshes,
exposes auth JSON, or includes bearer credentials.

## Host callback and HTTP bridge boundaries

A refresh uses only these CPA host-owned boundaries:

1. `host.auth.list` lists runtime auth entries.
2. `host.auth.get` retrieves one auth JSON payload by `auth_index`. The plugin
   extracts the short-lived provider credential in memory only; it never reads
   an auth file path directly and never includes credential fields in a
   snapshot or error response.
3. `host.http.do` sends each upstream quota request. The plugin does not use
   `net/http` directly for provider traffic. CPA therefore retains control of
   proxy policy, request logging, and transport behavior.

The plugin does not call `host.auth.save`, `host.auth.get_runtime`, or any
host-model callback. `host.http.do_stream` is not needed because every quota
endpoint used here is a bounded JSON response.

The host callback ID received with `management.handle` is forwarded on HTTP
bridge requests so CPA can preserve request context. Provider HTTP status
codes and malformed payloads become per-account quota errors; they are not
logged with response bodies or credentials. In a direct unit-test construction
of the core package, `Host.Call` and `Host.HTTP` are injected interfaces; the
C ABI adapter wires those interfaces to CPA's native callback table.

The plugin borrows CPA's callback context only while a native host call is in
progress. It never frees or retains that context. CPA must keep its callback
registry entry and native host allocations alive until the underlying plugin
call has returned; a canceled Go context does not by itself interrupt a C ABI
call or make unloading safe.

## Snapshot shape

The response uses AccessDeck's shared quota account shape:

```json
{
  "schema_version": 1,
  "last_updated_at": "2026-01-01T00:00:00Z",
  "last_attempt_at": "2026-01-01T00:00:00Z",
  "accounts": [
    {
      "account": {
        "id": "opaque-auth-id",
        "authIndex": "opaque-auth-index",
        "name": "auth-file.json",
        "provider": "codex",
        "providerRaw": "codex",
        "status": "active"
      },
      "snapshot": {
        "planType": "plus",
        "windows": [
          {
            "id": "5h",
            "label": "5h",
            "remainingPercent": 80,
            "resetText": "2h 10m"
          }
        ],
        "error": null
      }
    }
  ],
  "error": null
}
```

The example contains only opaque identifiers and illustrative values; it is
not a credential fixture. A failed top-level refresh preserves the last
successful account array and updates `last_attempt_at` and `error`, matching
AccessDeck's cache behavior. Per-account failures stay on that
account's `snapshot.error` field so one broken credential does not hide the
others.

## CPA configuration

Build the dynamic library and place it in the directory configured by CPA's
plugin host. The basename must match the plugin ID:

```yaml
plugins:
  enabled: true
  dir: "plugins"
  configs:
    clipbar-quota:
      enabled: true
      priority: 1
      request_timeout_seconds: 30
      max_concurrency: 8
```

The plugin configuration contains no secret fields. CPA's management
credential and the provider credentials remain host-owned.

## Build and test metadata

The Makefile follows CPA's example layout and chooses the platform extension:

- `.dylib` on macOS
- `.so` on Linux
- `.dll` on Windows

The local build target is a normal `go build -buildmode=c-shared`; it is not a
release/archive target and does not push, publish, or deploy anything. This
repository intentionally does not run or load that target during migration
validation. Focused unit tests use mocked host callbacks and HTTP responses:

```bash
make test
make check
# Local development build only, when explicitly needed:
make build
```

`bin/` and generated C headers are ignored by the plugin-local `.gitignore`.
No management key, backend access token, provider token, or auth JSON should
be placed in source, documentation, tests, build metadata, logs, or commits.
