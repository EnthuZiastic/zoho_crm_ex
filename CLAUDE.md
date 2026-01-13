# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir library that provides a client wrapper for multiple Zoho APIs:
- **Zoho CRM API** - Core CRM operations (records CRUD, search, bulk operations, composite API)
- **Zoho Desk API** - Ticket management
- **Zoho WorkDrive API** - File and folder operations
- **Zoho Recruit API** - Recruitment management (candidates, jobs)
- **Zoho Bookings API** - Appointment booking and scheduling
- **Zoho Projects API** - Project management (tasks, comments, users)

The library uses a builder pattern with two main request structures:
- `ZohoAPI.Request` - Low-level HTTP request builder
- `ZohoAPI.InputRequest` - High-level API input abstraction

## Development Commands

### Build and Dependencies
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile
```

### Testing
```bash
# Run all tests
mix test

# Run a specific test file
mix test test/zoho_api/modules/crm/records_test.exs

# Run tests with coverage
mix test --cover
```

### Code Quality
```bash
# Format code (must pass before committing)
mix format

# Check formatting without making changes
mix format --check-formatted

# Run static code analysis with Credo
mix credo

# Run strict Credo checks
mix credo --strict

# Type checking with Dialyzer
mix dialyzer
```

## Architecture

### Core Request Flow

All API calls follow this pattern:

```
InputRequest -> construct_request() -> Request -> HTTPoison -> Response
```

1. **InputRequest** (`lib/zoho_api/input_request.ex`) - User-facing struct containing:
   - `access_token` (required)
   - `module_api_name` - Zoho module name (e.g., "Leads", "Contacts")
   - `query_params` - URL query parameters
   - `body` - Request payload
   - `org_id` - Organization ID (required for Desk API)

2. **Request** (`lib/zoho_api/request.ex`) - Internal HTTP request builder with:
   - Builder methods: `with_path/2`, `with_method/2`, `with_body/2`, `set_access_token/2`, `with_region/2`
   - API type routing: `construct_url/1` handles different API types
   - Multi-region support: All major Zoho data centers supported
   - Response handling: Auto-decodes JSON, returns `{:ok, data}` or `{:error, reason}`

3. **Module-specific constructors** - Each API module has a private `construct_request/1` function that:
   - Creates appropriate Request struct with correct API type
   - Sets base URL, version, and authentication
   - Wraps body data in module-specific format (e.g., `%{"data" => body}`)

### API Module Structure

```
lib/zoho_api/modules/
├── crm/
│   ├── records.ex      # CRM CRUD operations (api_type: "crm")
│   ├── bulk_read.ex    # Bulk read operations (api_type: "bulk")
│   ├── bulk_write.ex   # Bulk write operations (api_type: "bulk")
│   └── composite.ex    # Composite API (api_type: "composite")
├── desk/
│   └── tickets.ex      # Desk tickets (api_type: "desk")
├── workdrive/
│   ├── files.ex        # WorkDrive files (api_type: "workdrive")
│   └── folders.ex      # WorkDrive folders (api_type: "workdrive")
├── recruit/
│   └── records.ex      # Recruit API (api_type: "recruit")
├── token.ex            # OAuth token refresh (api_type: "oauth")
├── bookings.ex         # Bookings API (api_type: "bookings")
├── projects.ex         # Projects API (api_type: "portal")
└── records.ex          # DEPRECATED: Legacy wrapper for CRM.Records
```

Each module follows the pattern:
- Public functions take `%InputRequest{}` as first parameter
- Private `construct_request/1` builds the base Request
- Chain builder methods to add path, method, params
- Call `Request.send/1` to execute

### API Type Routing

The `Request.construct_url/1` function pattern matches on `api_type` and uses region-specific URLs:

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

### Key Patterns

#### Builder Pattern
All request construction uses method chaining:
```elixir
Request.new("crm")
|> Request.set_access_token(token)
|> Request.with_method(:get)
|> Request.with_path("Leads")
|> Request.with_region(:com)
|> Request.send()
```

#### Body Wrapping
- CRM/Recruit: Wrap in `%{"data" => body}`
- Bookings (form data): Use `application/x-www-form-urlencoded` headers
- Desk/WorkDrive: Body passed as-is with JSON:API format
- Projects: Body passed as-is

#### Multi-Region Support
```elixir
# Token module
Token.refresh_access_token(refresh_token, region: :eu, service: :crm)

# Request builder
Request.new("crm")
|> Request.with_region(:com)
```

Supported regions: `:in`, `:com`, `:eu`, `:au`, `:jp`, `:uk`, `:ca`, `:sa`

## Configuration

The library expects configuration in `config/config.exs`:

```elixir
# Per-service configuration (recommended)
config :zoho_api, :crm,
  client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}

config :zoho_api, :desk,
  client_id: {:system, "ZOHO_DESK_CLIENT_ID"},
  client_secret: {:system, "ZOHO_DESK_CLIENT_SECRET"},
  org_id: {:system, "ZOHO_DESK_ORG_ID"}

# Legacy configuration (still supported for :crm)
config :zoho_api, :zoho,
  client_id: {:system, "ZOHO_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIENT_SECRET"}
```

Values can be:
- Direct strings: `"actual_value"`
- System env vars: `{:system, "ENV_VAR_NAME"}`

Access via `ZohoAPI.Config.get_config(:crm)` which raises if not configured.

## Code Style

- Maximum line length: 120 characters (enforced by Credo)
- Use `mix format` before committing (enforced by `.formatter.exs`)
- Module documentation required for all public modules
- Type specs required for all public functions
- Follow builder pattern for request construction
- Private helper functions should be named `construct_request/1` for consistency

## Important Notes

- All API responses are automatically JSON-decoded when possible
- HTTP methods are atoms: `:get`, `:post`, `:put`, `:delete`, `:patch`
- Access tokens must be refreshed using `ZohoAPI.Modules.Token.refresh_access_token/2`
- The library supports all major Zoho data center regions
- Zoho Desk API requires `org_id` - set via `InputRequest.with_org_id/2`
- Bulk operations have limits: 25,000 records for write, 200,000 for read
- Composite API allows max 5 requests per call

## Testing with Mox

The library uses Mox for HTTP mocking in tests:

```elixir
# test/test_helper.exs
Mox.defmock(ZohoAPI.HTTPClientMock, for: ZohoAPI.HTTPClient)
Application.put_env(:zoho_api, :http_client, ZohoAPI.HTTPClientMock)
```

```elixir
# In tests
expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, headers ->
  {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"data" => []})}}
end)
```
