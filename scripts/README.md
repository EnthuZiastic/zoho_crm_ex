# Test Scripts

Manual integration test scripts for verifying ZohoAPI functionality with real API keys.

## Setup

1. Copy the example configuration:
   ```bash
   cp scripts/config.example.exs scripts/config.exs
   ```

2. Edit `scripts/config.exs` with your real Zoho API credentials:
   - Get OAuth credentials from [Zoho API Console](https://api-console.zoho.com/)
   - Generate a refresh token with appropriate scopes

3. Run any test script:
   ```bash
   mix run scripts/test_crm.exs
   ```

## Available Test Scripts

| Script | Description | Requirements |
|--------|-------------|--------------|
| `test_crm.exs` | CRM records CRUD, search, client with retry | CRM API access |
| `test_desk.exs` | Desk tickets, departments, agents | Desk API access + org_id |
| `test_workdrive.exs` | WorkDrive teams, files, folders | WorkDrive API access |
| `test_bulk.exs` | Bulk read/write jobs | CRM Bulk API access |
| `test_composite.exs` | Composite API multi-request | CRM API access |
| `test_pagination.exs` | Streaming and pagination helpers | CRM API access |

## Configuration Reference

```elixir
%{
  # OAuth (required)
  client_id: "YOUR_CLIENT_ID",
  client_secret: "YOUR_CLIENT_SECRET",
  refresh_token: "YOUR_REFRESH_TOKEN",
  access_token: nil,  # Optional, will be refreshed automatically

  # Region (default: :in)
  region: :in,  # :in, :com, :eu, :au, :jp, :uk, :ca, :sa

  # CRM config
  crm: %{
    module: "Leads",      # Module to test
    record_id: nil        # Specific record for get/update tests
  },

  # Desk config (requires separate OAuth scope)
  desk: %{
    org_id: "YOUR_ORG_ID",  # Required for Desk API
    department_id: nil      # Optional
  },

  # WorkDrive config
  workdrive: %{
    team_folder_id: nil     # For folder tests
  },

  # Bulk API config
  bulk: %{
    module: "Leads",
    csv_file_path: nil      # Path to CSV for bulk write test
  }
}
```

## OAuth Scopes

Different APIs require different OAuth scopes:

- **CRM**: `ZohoCRM.modules.ALL`, `ZohoCRM.bulk.ALL`
- **Desk**: `Desk.tickets.ALL`, `Desk.basic.ALL`
- **WorkDrive**: `WorkDrive.files.ALL`, `WorkDrive.team.ALL`

## Notes

- `scripts/config.exs` is gitignored - your credentials won't be committed
- Test scripts create temporary records and clean them up
- Some tests may skip if optional configuration is missing
- Bulk write tests require a CSV file with proper format
