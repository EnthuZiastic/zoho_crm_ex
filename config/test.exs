# This file is responsible for configuring your application
# and its dependencies for the test environment.
import Config

config :zoho_api, :zoho,
  client_id: {:system, "ZOHO_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_REFRESH_TOKEN"}

config :zoho_api, :http_client, ZohoAPI.HTTPClientMock
