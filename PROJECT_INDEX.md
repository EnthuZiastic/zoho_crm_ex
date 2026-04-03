# PROJECT_INDEX.md

Generated: 2026-04-03
Elixir version: ~> 1.17 | Library version: 0.2.0

---

## 1. Repository Layout

```
zoho_ex/
  lib/
    zoho_api.ex                         # Top-level module (application entry)
    zoho_api/
      # Core infrastructure
      config.ex                         # Per-service credential loading (env-var aware)
      http_client.ex                    # HTTPClient behaviour (Mox-friendly)
      req_client.ex                     # Default Req-backed implementation
      input_request.ex                  # User-facing request struct (builder API)
      request.ex                        # Low-level HTTP builder + URL routing
      client.ex                         # Orchestration: retry + token refresh + rate limit
      token_cache.ex                    # GenServer: coordinated token refresh
      retry.ex                          # Exponential backoff with jitter
      rate_limiter.ex                   # Optional PostgreSQL-backed rate limiter
      pagination.ex                     # stream_all/3 and fetch_all/3 helpers
      regions.ex                        # Region atom -> URL mapping (8 regions)
      validation.ex                     # ID/path injection guard

      # High-level clients (TokenCache-based, no InputRequest)
      cliq.ex                           # ZohoAPI.Cliq  – Cliq messaging
      meeting.ex                        # ZohoAPI.Meeting – meeting sessions
      projects.ex                       # ZohoAPI.Projects – Projects façade
      bookings.ex                       # ZohoAPI.Bookings – Bookings façade
      crm.ex                            # ZohoAPI.CRM – CRM façade
      recruit.ex                        # ZohoAPI.Recruit – Recruit façade

      # Low-level module implementations (InputRequest-based)
      modules/
        token.ex                        # OAuth token refresh
        records.ex                      # DEPRECATED – use modules/crm/records.ex
        bookings.ex
        projects.ex
        meeting.ex
        crm/
          records.ex                    # CRM CRUD, upsert, search, COQL, pagination
          bulk_read.ex
          bulk_write.ex
          composite.ex                  # Multi-request composite calls
        desk/
          tickets.ex
        recruit/
          records.ex
        workdrive/
          files.ex
          folders.ex
        bulk/                           # Older bulk namespace (delegates to crm/bulk*)
          read.ex
          write.ex
  test/
    test_helper.exs                     # Mox mock setup + ExUnit.start()
    zoho_api_test.exs
    zoho_api/                           # Mirrors lib structure 1:1
      ...
  config/                               # Standard Mix config directory
  scripts/
  mix.exs
  mix.lock
  MIGRATION.md
  CLAUDE.md
```

---

## 2. Core Abstractions

### 2.1 Request Pipeline

```
Caller
  -> InputRequest (user-facing builder)
  -> Client.send/2                         (orchestration layer)
      -> RateLimiter.execute/2             (optional, PostgreSQL-backed)
          -> Retry.with_retry/2            (exponential backoff)
              -> Request.send_raw/1        (401 → TokenCache refresh → retry once)
                  -> HTTPClient.impl/0     (behaviour: ReqClient or mock)
                      -> Req (HTTP)
```

### 2.2 Two Client Patterns

**Pattern A – InputRequest-based** (CRM, Desk, WorkDrive, Recruit, Bookings, Projects, Bulk, Composite)

- Caller builds `%InputRequest{}` with `access_token`, `module_api_name`, `body`, `query_params`, `region`.
- Module's private `construct_request/1` sets `api_type` and chains `Request` builder methods.
- Calls either `Request.send/1` (simple) or `Client.send(request, input)` (with retry/refresh).
- Token refresh requires caller to set `refresh_token` and optionally `on_token_refresh` on the `InputRequest`.

**Pattern B – TokenCache-based** (`ZohoAPI.Cliq`, `ZohoAPI.Meeting`)

- Caller passes only business parameters (no tokens).
- Module calls `TokenCache.get_or_refresh(service)` to obtain a valid token.
- Credentials configured per-service in application config with `refresh_token`.
- Uses `ZohoAPI.Modules.*` internally for actual HTTP calls.

### 2.3 API Type -> URL Routing

All URL construction is in `Request.construct_url/1` via pattern-matching on `api_type`:

| api_type       | Base URL pattern                                    |
|----------------|-----------------------------------------------------|
| `"crm"`        | `https://www.zohoapis.{r}/crm/v8/{path}`           |
| `"desk"`       | `https://desk.zoho.{r}/api/v1/{path}`              |
| `"workdrive"`  | `https://www.zohoapis.{r}/workdrive/api/v1/{path}` |
| `"recruit"`    | `https://recruit.zoho.{r}/recruit/v2/{path}`       |
| `"bookings"`   | `https://www.zohoapis.{r}/bookings/v1/{path}`      |
| `"oauth"`      | `{base_url}/oauth/v2/{path}` (overridable)         |
| `"portal"`     | `https://projectsapi.zoho.{r}/restapi{path}`       |
| `"bulk"`       | `https://www.zohoapis.{r}/crm/bulk/v8/{path}`      |
| `"recruit_bulk"` | `https://recruit.zoho.{r}/recruit/bulk/v2/{path}` |
| `"composite"`  | `https://www.zohoapis.{r}/crm/v8/__composite_requests` |
| `"cliq"`       | `https://cliq.zoho.{r}/api/v2/{path}`             |
| `"meeting"`    | `https://meeting.zoho.{r}/api/v2/{path}`          |
| `"drive"`      | alias for `"workdrive"`                             |

Regions: `:in` `:com` `:eu` `:au` `:jp` `:uk` `:ca` `:sa` (default `:in`)

### 2.4 Body Encoding by API Type

- CRM / Recruit / Bulk / Composite: body wrapped in `%{"data" => body}`.
- Bookings / Projects: `application/x-www-form-urlencoded` via `{:form, list()}`.
- Desk / WorkDrive / Meeting: JSON, body passed as-is.

---

## 3. Key Modules – Responsibilities

| Module | Responsibility |
|--------|---------------|
| `ZohoAPI.InputRequest` | User-facing struct; builder for access_token, module, body, region, retry_opts, rate_limit_opts, refresh callbacks |
| `ZohoAPI.Request` | Low-level HTTP struct; builder pattern; URL construction; `send/1` and `send_raw/1`; error logging with hints |
| `ZohoAPI.Client` | Orchestrates rate limiting -> retry -> token refresh; `send/2` and `send_without_rate_limit/2` |
| `ZohoAPI.TokenCache` | GenServer; prevents duplicate concurrent refresh storms; TTL-based cache; `get_or_refresh/1`, `refresh_token/4`, `put_token/2`, `invalidate/1` |
| `ZohoAPI.Retry` | Exponential backoff with jitter; respects `Retry-After` on 429; retries network errors and 5xx; configurable per-request |
| `ZohoAPI.RateLimiter` | Optional PostgreSQL-backed rate limiting via `rate_limiter` dependency; no-op when not configured |
| `ZohoAPI.Pagination` | `stream_all/3` (lazy `Stream.resource`) and `fetch_all/3` (eager); handles Zoho `info.more_records` pagination format |
| `ZohoAPI.Regions` | Compile-time maps of region atom -> service URL; `validate!/1`, `oauth_url/1`, `api_url/2` |
| `ZohoAPI.Validation` | `validate_id/1` – guards against path traversal and injection in user-provided IDs |
| `ZohoAPI.Config` | Runtime credential loading from app env; `{:system, "VAR"}` tuple resolution; `get_config/1` |
| `ZohoAPI.HTTPClient` | Behaviour (`@callback request/5`); `impl/0` returns configured implementation (default `ReqClient`) |
| `ZohoAPI.ReqClient` | `Req`-backed implementation; translates `{:form, data}` bodies; maps timeout opts to Req conventions |
| `ZohoAPI.Modules.CRM.Records` | Full CRUD + upsert + search + COQL; `stream_all/2`, `fetch_all_records/2`; both simple and Client-based variants |
| `ZohoAPI.Modules.CRM.Composite` | Up to 5 sub-requests per call; sequential (`parallel_execution: false`) and parallel modes; placeholder syntax `@{id:$.path}` |
| `ZohoAPI.Modules.CRM.BulkWrite` | Bulk write jobs (max 25,000 records) |
| `ZohoAPI.Modules.CRM.BulkRead` | Bulk read jobs (max 200,000 records) |
| `ZohoAPI.Modules.Desk.Tickets` | Zoho Desk tickets; requires `org_id` header |
| `ZohoAPI.Modules.Projects` | Tasks, comments via portal/project IDs; form-encoded bodies |
| `ZohoAPI.Modules.Recruit.Records` | Recruit module CRUD |
| `ZohoAPI.Modules.WorkDrive.Files` | File operations |
| `ZohoAPI.Modules.WorkDrive.Folders` | Folder operations |
| `ZohoAPI.Modules.Token` | Low-level OAuth token refresh (calls accounts.zoho.{region}/oauth/v2/token) |
| `ZohoAPI.Cliq` | High-level Cliq client; auto-fetches token via TokenCache; `create_message/2` |
| `ZohoAPI.Meeting` | High-level Meeting client; auto-fetches token; create/list/delete sessions, participant reports, recordings |

---

## 4. Test Structure

- **27 test files** mirroring `lib/` layout under `test/zoho_api/`.
- **Mock setup** in `test/test_helper.exs`:
  ```elixir
  Mox.defmock(ZohoAPI.HTTPClientMock, for: ZohoAPI.HTTPClient)
  Application.put_env(:zoho_api, :http_client, ZohoAPI.HTTPClientMock)
  ```
- All tests use `use ExUnit.Case, async: true` and `setup :verify_on_exit!`.
- Tests mock at the `HTTPClient` boundary (the `request/5` callback) — no real HTTP calls.
- `expect(ZohoAPI.HTTPClientMock, :request, fn method, url, body, headers, opts -> ... end)` is the standard pattern.
- `test/support/` (elixirc_paths in `:test`) available for shared helpers.

Key test files:
- `/Users/pratik/code/zoho_ex/test/zoho_api/modules/crm/records_test.exs` – representative CRUD tests
- `/Users/pratik/code/zoho_ex/test/zoho_api/modules/crm/composite_test.exs` – composite API tests
- `/Users/pratik/code/zoho_ex/test/zoho_api/token_cache_test.exs` – concurrency/storm prevention tests
- `/Users/pratik/code/zoho_ex/test/zoho_api/retry_test.exs` – backoff and 429 handling
- `/Users/pratik/code/zoho_ex/test/zoho_api/pagination_test.exs` – stream and fetch_all

---

## 5. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `req` | `~> 0.5` | HTTP client (production) |
| `jason` | `~> 1.4` | JSON encode/decode |
| `credo` | `~> 1.7.15` | Static analysis (dev/test) |
| `dialyxir` | `~> 1.4` | Type checking (dev/test) |
| `mox` | `~> 1.2` | HTTP mock in tests |
| `rate_limiter` | optional | PostgreSQL-backed rate limiting (external dep, not in mix.exs) |

---

## 6. Configuration Reference

```elixir
# Per-service OAuth credentials
config :zoho_api, :crm,
  client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_CRM_REFRESH_TOKEN"},
  region: :com

config :zoho_api, :desk,
  client_id: {:system, "ZOHO_DESK_CLIENT_ID"},
  client_secret: {:system, "ZOHO_DESK_CLIENT_SECRET"},
  org_id: {:system, "ZOHO_DESK_ORG_ID"}

config :zoho_api, :meeting,
  client_id: {:system, "ZOHO_MEETING_CLIENT_ID"},
  client_secret: {:system, "ZOHO_MEETING_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_MEETING_REFRESH_TOKEN"},
  region: :com

config :zoho_api, :cliq,
  client_id: {:system, "ZOHO_CLIQ_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIQ_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_CLIQ_REFRESH_TOKEN"}

# Token cache
config :zoho_api, :token_cache,
  ttl_seconds: 3500,               # default 3500 (< Zoho's 1h expiry)
  name: ZohoAPI.TokenCache,        # override for Horde cluster-wide sharing
  refresh_timeout_ms: 60_000

# HTTP timeouts
config :zoho_api, :http_timeout, 30_000   # global default (ms)

# Retry
config :zoho_api, :retry,
  enabled: true,
  max_retries: 3,
  base_delay_ms: 1000,
  max_delay_ms: 30_000,
  jitter: true

# Rate limiter (requires rate_limiter dep)
config :zoho_api, :rate_limiter,
  enabled: false,
  repo: MyApp.Repo,
  key: "zoho_api",
  request_count: 100,
  time_window: 60
```

---

## 7. Notable Architectural Decisions

1. **Behaviour-based HTTP client** — `ZohoAPI.HTTPClient` defines a single `request/5` callback. `ReqClient` wraps `Req`. In tests, `ZohoAPI.HTTPClientMock` (via Mox) is injected via `Application.put_env`. No real HTTP calls in any test.

2. **Dual client patterns** — InputRequest-based modules (most of the library) require the caller to supply and refresh tokens. TokenCache-based clients (`Cliq`, `Meeting`) self-manage tokens from app config. The two patterns coexist intentionally for different use cases.

3. **TokenCache storm prevention** — `TokenCache` GenServer serializes concurrent token refreshes per service. If 10 processes all hit 401 simultaneously, only one `Token.refresh_access_token/1` call is issued; the other 9 await the `{:refresh_complete, service, result}` message via `handle_info`.

4. **TokenCache name override** — The GenServer name is resolved from `config :zoho_api, :token_cache, name: ...`, allowing the host application (e.g., `enthu-backend`) to register it under Horde for cluster-wide token sharing without any library changes.

5. **Composite API correctness** — Sequential mode uses `parallel_execution: false` (NOT `concurrent_execution: false` which is a stale name). The endpoint path field is ignored; individual paths go in each sub-request's `url` field; the `sub_request_id` field (not `reference_id`) is used for placeholders.

6. **Deprecated module** — `ZohoAPI.Modules.Records` is kept for backward compatibility but all new code should use `ZohoAPI.Modules.CRM.Records`.

7. **Path injection prevention** — All user-provided IDs pass through `Validation.validate_id/1` before being interpolated into URL paths. Rejects `..`, `/`, `\`, and non-alphanumeric-hyphen-underscore characters.

8. **Form-encoded bodies** — Projects API and Bookings API require `application/x-www-form-urlencoded`. The `{:form, list()}` body tuple is handled in `Request.encode_body/1` and serialized in `ReqClient.request/5` via `URI.encode_query/1`.

9. **Environment variables resolved at runtime** — `Config.get_config/1` calls `System.get_env/1` at call time, not compile time. Supports same compiled release across environments.

10. **Retry-After header respected on 429** — `Retry` parses `retry_after` / `Retry-After` from response body (Zoho embeds it in JSON, not HTTP headers) and uses it as sleep duration instead of exponential backoff.

---

## 8. Entry Points for Common Tasks

| Task | Entry point |
|------|-------------|
| Fetch CRM records | `ZohoAPI.Modules.CRM.Records.get_records/1` |
| Stream all CRM records | `ZohoAPI.Modules.CRM.Records.stream_all/2` |
| Upsert CRM records | `ZohoAPI.Modules.CRM.Records.upsert_records/2` |
| COQL query | `ZohoAPI.Modules.CRM.Records.coql_query/1` |
| Composite API | `ZohoAPI.Modules.CRM.Composite.execute/1` |
| Bulk write | `ZohoAPI.Modules.CRM.BulkWrite` |
| Desk tickets | `ZohoAPI.Modules.Desk.Tickets` (needs `org_id`) |
| Projects tasks | `ZohoAPI.Modules.Projects.list_tasks/3` |
| Send Cliq message | `ZohoAPI.Cliq.create_message/2` |
| Create meeting | `ZohoAPI.Meeting.create_session/2` |
| Refresh OAuth token | `ZohoAPI.Modules.Token.refresh_access_token/2` |
| Token cache manual set | `ZohoAPI.TokenCache.put_token/2` |
| Multi-service token cache | `ZohoAPI.TokenCache.get_or_refresh/1` |
