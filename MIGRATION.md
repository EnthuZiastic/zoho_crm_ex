# Migration Guide

## Migrating from v0.1.x to v0.2.0

Version 0.2.0 introduces breaking changes including a module rename and new features.

### Module Rename: ZohoCrm to ZohoAPI

All modules have been renamed from `ZohoCrm` to `ZohoAPI`:

| Old Module | New Module |
|------------|------------|
| `ZohoCrm` | `ZohoAPI` |
| `ZohoCrm.Config` | `ZohoAPI.Config` |
| `ZohoCrm.Request` | `ZohoAPI.Request` |
| `ZohoCrm.InputRequest` | `ZohoAPI.InputRequest` |
| `ZohoCrm.HTTPClient` | `ZohoAPI.HTTPClient` |
| `ZohoCrm.Modules.Records` | `ZohoAPI.Modules.CRM.Records` |
| `ZohoCrm.Modules.Token` | `ZohoAPI.Modules.Token` |
| `ZohoCrm.Modules.Bookings` | `ZohoAPI.Modules.Bookings` |
| `ZohoCrm.Modules.Projects` | `ZohoAPI.Modules.Projects` |
| `ZohoCrm.Modules.Recruit.Records` | `ZohoAPI.Modules.Recruit.Records` |

### Configuration Changes

Update your config from `:zoho_crm` to `:zoho_api`:

```elixir
# Before (v0.1.x)
config :zoho_crm, :zoho,
  client_id: "your_client_id",
  client_secret: "your_client_secret"

# After (v0.2.0)
config :zoho_api, :crm,
  client_id: "your_client_id",
  client_secret: "your_client_secret"
```

### Multi-Service Configuration

v0.2.0 supports multiple Zoho services with separate credentials:

```elixir
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

### Records Module Location Change

The CRM Records module has moved:

```elixir
# Before (v0.1.x)
alias ZohoCrm.Modules.Records

Records.get_records(input)

# After (v0.2.0)
alias ZohoAPI.Modules.CRM.Records

Records.get_records(input)
```

A deprecated compatibility wrapper exists at `ZohoAPI.Modules.Records` but will be removed in a future version.

### New Features in v0.2.0

#### Multi-Region Support

All APIs now support multiple Zoho data center regions:

```elixir
# Token refresh with region
Token.refresh_access_token(refresh_token, region: :eu, service: :crm)

# Request with region
Request.new("crm")
|> Request.with_region(:com)
|> Request.with_path("Leads")
|> Request.send()
```

Supported regions: `:in` (India, default), `:com` (US), `:eu` (Europe), `:au` (Australia), `:jp` (Japan), `:uk` (UK), `:ca` (Canada), `:sa` (Saudi Arabia)

#### New API Modules

- `ZohoAPI.Modules.Desk.Tickets` - Zoho Desk ticket management
- `ZohoAPI.Modules.WorkDrive.Files` - WorkDrive file operations
- `ZohoAPI.Modules.WorkDrive.Folders` - WorkDrive folder operations
- `ZohoAPI.Modules.CRM.BulkRead` - Bulk read operations (up to 200k records)
- `ZohoAPI.Modules.CRM.BulkWrite` - Bulk write operations (up to 25k records)
- `ZohoAPI.Modules.CRM.Composite` - Composite API (up to 5 requests in one call)

#### InputRequest Changes

New field for Zoho Desk:

```elixir
input = InputRequest.new("access_token")
|> InputRequest.with_org_id("org_123")  # Required for Desk API
```

### Search and Replace Commands

To update your codebase, run these commands:

```bash
# Update module references
find lib test -name "*.ex" -o -name "*.exs" | xargs sed -i '' 's/ZohoCrm/ZohoAPI/g'

# Update config references
find lib test config -name "*.ex" -o -name "*.exs" | xargs sed -i '' 's/:zoho_crm/:zoho_api/g'

# Update dependency in mix.exs
sed -i '' 's/:zoho_crm/:zoho_api/g' mix.exs
```

### Dependency Update

```elixir
# mix.exs
def deps do
  [
    {:zoho_api, "~> 0.2.0"}
  ]
end
```
