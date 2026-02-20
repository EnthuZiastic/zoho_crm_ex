Mox.defmock(ZohoAPI.HTTPClientMock, for: ZohoAPI.HTTPClient)
Application.put_env(:zoho_api, :http_client, ZohoAPI.HTTPClientMock)

ExUnit.start()
