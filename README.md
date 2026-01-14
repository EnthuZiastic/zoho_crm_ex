# ZohoAPI

An Elixir client library for multiple Zoho APIs with multi-region and multi-service support.

## Supported APIs

- **Zoho CRM** - Records CRUD, search, COQL queries, bulk operations, composite API
- **Zoho Desk** - Ticket management
- **Zoho WorkDrive** - File and folder operations
- **Zoho Recruit** - Candidate and job management
- **Zoho Bookings** - Appointment scheduling
- **Zoho Projects** - Task and project management

## Requirements

- Elixir ~> 1.17
- Erlang/OTP 26+

## Installation

Add `zoho_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoho_api, "~> 0.2.0"}
  ]
end
```

### Optional Dependencies

For PostgreSQL-backed rate limiting, add the `rate_limiter` dependency:

```elixir
def deps do
  [
    {:zoho_api, "~> 0.2.0"},
    # Optional: PostgreSQL-backed rate limiting
    {:rate_limiter, github: "Enthuziastic/rate_limiter", optional: true}
  ]
end
```

The library works without this dependency - rate limiting is simply disabled.

## Configuration

Configure credentials for each Zoho service you need:

```elixir
# config/config.exs

# CRM credentials
config :zoho_api, :crm,
  client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}

# Desk credentials (requires org_id)
config :zoho_api, :desk,
  client_id: {:system, "ZOHO_DESK_CLIENT_ID"},
  client_secret: {:system, "ZOHO_DESK_CLIENT_SECRET"},
  org_id: {:system, "ZOHO_DESK_ORG_ID"}

# WorkDrive credentials
config :zoho_api, :workdrive,
  client_id: {:system, "ZOHO_WORKDRIVE_CLIENT_ID"},
  client_secret: {:system, "ZOHO_WORKDRIVE_CLIENT_SECRET"}
```

Values can be direct strings or environment variable references using `{:system, "VAR_NAME"}`.

## Usage

### Token Refresh

```elixir
alias ZohoAPI.Modules.Token

# Refresh access token (defaults to :crm service, :in region)
{:ok, %{"access_token" => token}} = Token.refresh_access_token(refresh_token)

# Refresh for specific service and region
{:ok, %{"access_token" => token}} = Token.refresh_access_token(refresh_token,
  service: :desk,
  region: :com
)
```

### CRM Operations

```elixir
alias ZohoAPI.InputRequest
alias ZohoAPI.Modules.CRM.Records

# Create input request
input = InputRequest.new("access_token")
|> InputRequest.with_module_api_name("Leads")

# Get records
{:ok, leads} = Records.get_records(input)

# Insert records
input = InputRequest.new("access_token")
|> InputRequest.with_module_api_name("Leads")
|> InputRequest.with_body([%{"Last_Name" => "Smith", "Email" => "smith@example.com"}])

{:ok, result} = Records.insert_records(input)

# Search with COQL
input = InputRequest.new("access_token")
|> InputRequest.with_body(%{
  "select_query" => "SELECT Last_Name, Email FROM Leads WHERE Email is not null LIMIT 100"
})

{:ok, result} = Records.coql_query(input)
```

### Desk Operations

```elixir
alias ZohoAPI.Modules.Desk.Tickets

# org_id is required for Desk API
input = InputRequest.new("access_token")
|> InputRequest.with_org_id("org_123")

{:ok, tickets} = Tickets.list_tickets(input)

# Create ticket
input = InputRequest.new("access_token")
|> InputRequest.with_org_id("org_123")
|> InputRequest.with_body(%{
  "subject" => "Help needed",
  "departmentId" => "dept_123",
  "contactId" => "contact_123"
})

{:ok, ticket} = Tickets.create_ticket(input)
```

### WorkDrive Operations

```elixir
alias ZohoAPI.Modules.WorkDrive.{Files, Folders}

input = InputRequest.new("access_token")

# List folders
{:ok, folders} = Folders.list_folders(input, "team_folder_id")

# Upload file
input = InputRequest.new("access_token")
|> InputRequest.with_body(file_content)

{:ok, file} = Files.upload_file(input, "folder_id", "document.pdf")

# Download file
{:ok, content} = Files.download_file(input, "file_id")
```

### Bulk Operations

```elixir
alias ZohoAPI.Modules.CRM.{BulkWrite, BulkRead}

# Bulk Write (up to 25,000 records)
csv_content = "Last_Name,Email\nSmith,smith@example.com\nJones,jones@example.com"

input = InputRequest.new("access_token")
|> InputRequest.with_body(csv_content)

{:ok, %{"details" => %{"file_id" => file_id}}} = BulkWrite.upload_file(input, "Leads")

# Create bulk write job
job_config = %{
  "operation" => "insert",
  "resource" => [%{
    "type" => "data",
    "module" => %{"api_name" => "Leads"},
    "file_id" => file_id,
    "field_mappings" => [
      %{"api_name" => "Last_Name", "index" => 0},
      %{"api_name" => "Email", "index" => 1}
    ]
  }]
}

input = InputRequest.new("access_token")
|> InputRequest.with_body(job_config)

{:ok, %{"details" => %{"id" => job_id}}} = BulkWrite.create_job(input)

# Check job status
{:ok, status} = BulkWrite.get_job_status(input, job_id)
```

### Composite API

```elixir
alias ZohoAPI.Modules.CRM.Composite

# Execute up to 5 API calls in one request
input = InputRequest.new("access_token")
|> InputRequest.with_body(%{
  "__composite_requests" => [
    %{"method" => "GET", "reference_id" => "get_leads", "url" => "/crm/v8/Leads"},
    %{"method" => "POST", "reference_id" => "create_contact", "url" => "/crm/v8/Contacts",
      "body" => %{"data" => [%{"Last_Name" => "New Contact"}]}}
  ]
})

{:ok, %{"__composite_responses" => responses}} = Composite.execute(input)

# Sequential execution with data reference (search + update)
# IMPORTANT: Use "parallel_execution", NOT "concurrent_execution"
input = InputRequest.new("access_token")
|> InputRequest.with_body(%{
  "parallel_execution" => false,
  "__composite_requests" => [
    %{"method" => "GET", "reference_id" => "1", "url" => "/crm/v8/Contacts/search",
      "params" => %{"criteria" => "(Email:equals:test@example.com)"}},
    %{"method" => "PUT", "reference_id" => "2", "url" => "/crm/v8/Contacts/@{1:$.data[0].id}",
      "body" => %{"data" => [%{"Phone" => "555-1234"}]}}
  ]
})

{:ok, result} = Composite.execute(input)
```

### Pagination

For modules with many records, use streaming pagination for memory-efficient processing:

```elixir
alias ZohoAPI.Modules.CRM.Records

input = InputRequest.new("access_token")
|> InputRequest.with_refresh_token("refresh_token")
|> InputRequest.with_module_api_name("Leads")

# Stream lazily - only one page in memory at a time
Records.stream_all(input)
|> Stream.filter(&(&1["Status"] == "Active"))
|> Stream.take(1000)
|> Enum.to_list()

# Or fetch all at once (loads everything into memory)
{:ok, all_leads} = Records.fetch_all_records(input)

# With options
Records.stream_all(input, per_page: 100, max_records: 5000)
|> Enum.each(&process_lead/1)
```

See `ZohoAPI.Pagination` module documentation for advanced usage.

## Multi-Region Support

All APIs support multiple Zoho data center regions:

| Region | Code | Description |
|--------|------|-------------|
| India | `:in` | Default |
| United States | `:com` | |
| Europe | `:eu` | |
| Australia | `:au` | |
| Japan | `:jp` | |
| United Kingdom | `:uk` | |
| Canada | `:ca` | |
| Saudi Arabia | `:sa` | |

```elixir
# Using region with token refresh
Token.refresh_access_token(refresh_token, region: :eu)

# Using region with Request builder
Request.new("crm")
|> Request.with_region(:com)
|> Request.with_path("Leads")
|> Request.send()
```

## Error Handling

All API functions return `{:ok, result}` or `{:error, reason}`:

```elixir
case Records.get_records(input) do
  {:ok, %{"data" => records}} ->
    # Handle success

  {:error, %{"code" => "INVALID_TOKEN"}} ->
    # Handle invalid/expired token

  {:error, reason} ->
    # Handle other errors
end
```

## Migration from v0.1.x

See [MIGRATION.md](MIGRATION.md) for upgrade instructions.

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Code quality
mix format
mix credo --strict
mix dialyzer
```

## License

MIT License
