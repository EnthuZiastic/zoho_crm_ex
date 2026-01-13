Mox.defmock(ZohoCrm.HTTPClientMock, for: ZohoCrm.HTTPClient)
Application.put_env(:zoho_crm, :http_client, ZohoCrm.HTTPClientMock)

ExUnit.start()
