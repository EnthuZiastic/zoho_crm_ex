defmodule ZohoAPI do
  @moduledoc """
  Elixir client library for multiple Zoho APIs.

  ## Supported APIs

    - **Zoho CRM** - Records CRUD, search, COQL queries, bulk operations, composite API
    - **Zoho Desk** - Ticket management
    - **Zoho WorkDrive** - File and folder operations
    - **Zoho Recruit** - Candidate and job management
    - **Zoho Bookings** - Appointment scheduling
    - **Zoho Projects** - Task and project management

  ## Quick Start

      # 1. Get an access token
      {:ok, %{"access_token" => token}} = ZohoAPI.Modules.Token.refresh_access_token(refresh_token)

      # 2. Create an input request
      input = ZohoAPI.InputRequest.new(token)
      |> ZohoAPI.InputRequest.with_module_api_name("Leads")

      # 3. Call the API
      {:ok, leads} = ZohoAPI.Modules.CRM.Records.get_records(input)

  ## Configuration

  Configure credentials for each Zoho service:

      config :zoho_api, :crm,
        client_id: "your_client_id",
        client_secret: "your_client_secret"

      config :zoho_api, :desk,
        client_id: "your_client_id",
        client_secret: "your_client_secret",
        org_id: "your_org_id"

  See `ZohoAPI.Config` for more details.
  """
end
