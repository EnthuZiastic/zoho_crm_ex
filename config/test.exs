# This file is responsible for configuring your application
# and its dependencies for the test environment.
import Config

config :zoho_api, :zoho,
  client_id: {:system, "ZOHO_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_REFRESH_TOKEN"}

# Test config for CRM service (used by Client tests)
config :zoho_api, :crm,
  client_id: "test_client_id",
  client_secret: "test_client_secret"

config :zoho_api, :http_client, ZohoAPI.HTTPClientMock
