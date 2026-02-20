# Example configuration for test scripts
# Copy this file to config.exs and fill in your real values
#
# Usage:
#   cp scripts/config.example.exs scripts/config.exs
#   # Edit scripts/config.exs with your real API keys
#   mix run scripts/test_crm.exs

%{
  # Current access token (optional, will be refreshed automatically)
  access_token: nil,

  # Region - :in, :com, :eu, :au, :jp, :uk, :ca, :sa
  region: :in,

  # CRM Configuration
  # Get OAuth credentials from Zoho API Console: https://api-console.zoho.com/
  crm: %{
    client_id: "YOUR_CRM_CLIENT_ID",
    client_secret: "YOUR_CRM_CLIENT_SECRET",
    refresh_token: "YOUR_CRM_REFRESH_TOKEN",
    # Module to test (e.g., "Leads", "Contacts", "Deals")
    module: "Leads",
    # Specific record ID for get/update tests (optional)
    record_id: nil
  },

  # Desk Configuration (requires separate OAuth scope)
  desk: %{
    # Per-service credentials (can be different from CRM)
    client_id: "YOUR_DESK_CLIENT_ID",
    client_secret: "YOUR_DESK_CLIENT_SECRET",
    refresh_token: "YOUR_DESK_REFRESH_TOKEN",
    # Organization ID (required for Desk API)
    org_id: "YOUR_ORG_ID",
    # Department ID for ticket tests
    department_id: nil
  },

  # WorkDrive Configuration
  workdrive: %{
    # Team folder ID for file tests
    team_folder_id: nil
  },

  # Bulk API Configuration
  bulk: %{
    # Module for bulk operations
    module: "Leads",
    # CSV content for bulk write tests (optional)
    csv_file_path: nil
  }
}
