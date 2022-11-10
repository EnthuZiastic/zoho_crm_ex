use Mix.Config

config :zoho_crm, :zoho,
  client_id: {:system, "ZOHO_CLIENT_ID"},
  client_secret: {:system, "ZOHO_CLIENT_SECRET"},
  refresh_token: {:system, "ZOHO_REFRESH_TOKEN"}
