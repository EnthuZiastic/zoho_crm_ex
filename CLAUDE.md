# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir library that provides a client wrapper for multiple Zoho APIs:
- **Zoho CRM API** - Core CRM operations (records CRUD, search)
- **Zoho Recruit API** - Recruitment management (candidates, jobs)
- **Zoho Bookings API** - Appointment booking and scheduling
- **Zoho Projects API** - Project management (tasks, comments, users)

The library uses a builder pattern with two main request structures:
- `ZohoCrm.Request` - Low-level HTTP request builder
- `ZohoCrm.InputRequest` - High-level API input abstraction

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
mix test test/zoho_crm_test.exs

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
InputRequest → construct_request() → Request → HTTPoison → Response
```

1. **InputRequest** (`lib/zoho_crm/input_request.ex`) - User-facing struct containing:
   - `access_token` (required)
   - `module_api_name` - Zoho module name (e.g., "Leads", "Contacts")
   - `query_params` - URL query parameters
   - `body` - Request payload

2. **Request** (`lib/zoho_crm/request.ex`) - Internal HTTP request builder with:
   - Builder methods: `with_path/2`, `with_method/2`, `with_body/2`, `set_access_token/2`
   - API type routing: `construct_url/1` handles different API types (crm, recruit, bookings, oauth, portal)
   - Response handling: Auto-decodes JSON, returns `{:ok, data}` or `{:error, reason}`

3. **Module-specific constructors** - Each API module has a private `construct_request/1` function that:
   - Creates appropriate Request struct with correct API type
   - Sets base URL, version, and authentication
   - Wraps body data in module-specific format (e.g., `%{"data" => body}`)

### API Module Structure

```
lib/zoho_crm/modules/
├── records.ex          # CRM operations (api_type: "crm")
├── token.ex            # OAuth token refresh (api_type: "oauth")
├── bookings.ex         # Bookings API (api_type: "bookings", v1)
├── projects.ex         # Projects API (api_type: "portal")
└── recruit/
    └── records.ex      # Recruit API (api_type: "recruit", v2)
```

Each module follows the pattern:
- Public functions take `%InputRequest{}` as first parameter
- Private `construct_request/1` builds the base Request
- Chain builder methods to add path, method, params
- Call `Request.send/1` to execute

### API Type Routing

The `Request.construct_url/1` function pattern matches on `api_type`:
- **"crm"** → `https://www.zohoapis.in/crm/v8/{path}`
- **"recruit"** → `https://recruit.zoho.in/recruit/v2/{path}` (overrides base_url)
- **"bookings"** → `https://www.zohoapis.in/bookings/v1/{path}`
- **"oauth"** → `https://accounts.zoho.in/oauth/v2/{path}` (overrides base_url)
- **"portal"** → `https://projectsapi.zoho.in/restapi{path}` (custom base, no api_type prefix)

### Key Patterns

#### Builder Pattern
All request construction uses method chaining:
```elixir
Request.new("crm")
|> Request.set_access_token(token)
|> Request.with_method(:get)
|> Request.with_path("Leads")
|> Request.send()
```

#### Body Wrapping
- CRM/Recruit: Wrap in `%{"data" => body}`
- Bookings (form data): Use `application/x-www-form-urlencoded` headers
- Projects: Body passed as-is

#### Upsert Support
The `upsert_records/2` function supports a special `duplicate_check_fields` option:
```elixir
upsert_records(input_request, duplicate_check_fields: ["Email", "Phone"])
```
This merges the fields into the request body before sending.

## Configuration

The library expects configuration in `config/config.exs`:

```elixir
config :zoho_crm, :zoho,
  client_id: {:system, "ZOHO_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIENT_SECRET"}
```

Values can be:
- Direct strings: `"actual_value"`
- System env vars: `{:system, "ENV_VAR_NAME"}`

Access via `ZohoCrm.Config.get_config()` which raises if not configured.

## Code Style

- Maximum line length: 120 characters (enforced by Credo)
- Use `mix format` before committing (enforced by `.formatter.exs`)
- Module documentation required for all public modules
- Type specs required for all public functions
- Follow builder pattern for request construction
- Private helper functions should be named `construct_request/1` for consistency

## Important Notes

- All API responses are automatically JSON-decoded when possible
- HTTP methods are atoms: `:get`, `:post`, `:put`, `:delete`
- Access tokens must be refreshed using `ZohoCrm.Modules.Token.refresh_access_token/1`
- The library targets India data center (`.in` domains) - URLs would need updating for other regions
