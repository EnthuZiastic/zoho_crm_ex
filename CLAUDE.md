# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Elixir client library for multiple Zoho APIs (CRM, Desk, WorkDrive, Recruit, Bookings, Projects) with multi-region support, automatic retry, rate limiting, and token caching.

## Development Commands

```bash
mix deps.get                    # Install dependencies
mix compile                     # Compile
mix test                        # Run all tests
mix test path/to/test.exs:12    # Run specific test by line
mix format                      # Format code (required before commit)
mix credo --strict              # Static analysis
mix dialyzer                    # Type checking
```

## Architecture

### Request Flow

```
InputRequest -> construct_request() -> Request -> Retry -> RateLimiter -> HTTPoison -> Response
```

**Core modules:**
- `InputRequest` - User-facing struct with access_token, module_api_name, query_params, body, org_id
- `Request` - Low-level HTTP builder with `with_path/2`, `with_method/2`, `with_body/2`, `with_region/2`
- `Retry` - Exponential backoff for transient failures (429, 5xx, network errors)
- `RateLimiter` - Optional PostgreSQL-backed rate limiting via `rate_limiter` dependency
- `TokenCache` - GenServer for coordinated token refresh (prevents concurrent 401 refresh storms)
- `Pagination` - Streaming (`stream_all/3`) and eager (`fetch_all/3`) pagination helpers

### Module Pattern

Each API module in `lib/zoho_api/modules/` follows this pattern:
1. Public functions take `%InputRequest{}` as first parameter
2. Private `construct_request/1` builds base Request with correct `api_type`
3. Chain builder methods for path, method, params
4. Call `Request.send/1` to execute

### API Type Routing

`Request.construct_url/1` pattern matches on `api_type`:

| API Type | URL Pattern |
|----------|-------------|
| `"crm"` | `https://www.zohoapis.{region}/crm/v8/{path}` |
| `"desk"` | `https://desk.zoho.{region}/api/v1/{path}` |
| `"workdrive"` | `https://www.zohoapis.{region}/workdrive/api/v1/{path}` |
| `"recruit"` | `https://recruit.zoho.{region}/recruit/v2/{path}` |
| `"bookings"` | `https://www.zohoapis.{region}/bookings/v1/{path}` |
| `"oauth"` | `https://accounts.zoho.{region}/oauth/v2/{path}` |
| `"portal"` | `https://projectsapi.zoho.{region}/restapi{path}` |
| `"bulk"` | `https://www.zohoapis.{region}/crm/bulk/v8/{path}` |
| `"composite"` | `https://www.zohoapis.{region}/crm/v8/__composite_requests` |

Regions: `:in`, `:com`, `:eu`, `:au`, `:jp`, `:uk`, `:ca`, `:sa`

### Body Wrapping by API Type

- **CRM/Recruit**: Wrap in `%{"data" => body}`
- **Bookings**: `application/x-www-form-urlencoded`
- **Desk/WorkDrive/Projects**: Body passed as-is

## Configuration

```elixir
# Per-service credentials
config :zoho_api, :crm,
  client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}

config :zoho_api, :desk,
  client_id: {:system, "ZOHO_DESK_CLIENT_ID"},
  client_secret: {:system, "ZOHO_DESK_CLIENT_SECRET"},
  org_id: {:system, "ZOHO_DESK_ORG_ID"}

# Optional: Token cache TTL (default: 3500s)
config :zoho_api, :token_cache,
  ttl_seconds: 3500

# Optional: Retry configuration
config :zoho_api, :retry,
  enabled: true,
  max_retries: 3,
  base_delay_ms: 1000,
  max_delay_ms: 30_000

# Optional: Rate limiting (requires rate_limiter dependency)
config :zoho_api, :rate_limiter,
  enabled: true,
  repo: MyApp.Repo,
  request_count: 100,
  time_window: 60
```

## Testing with Mox

```elixir
# Tests use ZohoAPI.HTTPClientMock (defined in test/test_helper.exs)
defmodule MyTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "example" do
    expect(ZohoAPI.HTTPClientMock, :request, fn :get, _url, _body, _headers ->
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"data" => []})}}
    end)
  end
end
```

## Key Constraints

- Desk API requires `org_id` via `InputRequest.with_org_id/2`
- Bulk write: max 25,000 records; bulk read: max 200,000 records
- Composite API: max 5 requests per call
- `ZohoAPI.Modules.Records` is DEPRECATED - use `ZohoAPI.Modules.CRM.Records`
- Use `Validation.validate_id/1` for user-provided IDs to prevent path injection
