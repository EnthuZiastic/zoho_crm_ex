defmodule ZohoAPI.HTTPClient do
  @moduledoc """
  HTTP client behaviour for Zoho API requests.

  This module defines the behaviour for HTTP requests, allowing for
  easy mocking in tests using Mox.

  ## Default Implementation

  By default, HTTPoison is used as the HTTP client. All requests go through
  the `HTTPoison.request/5` function.

  ## Testing with Mox

  The behaviour-based design allows easy mocking in tests:

  ### Step 1: Add Mox to test dependencies

      # mix.exs
      defp deps do
        [
          {:mox, "~> 1.2", only: :test}
        ]
      end

  ### Step 2: Configure test_helper.exs

      # test/test_helper.exs
      ExUnit.start()

      Mox.defmock(ZohoAPI.HTTPClientMock, for: ZohoAPI.HTTPClient)
      Application.put_env(:zoho_api, :http_client, ZohoAPI.HTTPClientMock)

  ### Step 3: Use in tests

      defmodule MyApp.ZohoTest do
        use ExUnit.Case, async: true
        import Mox

        setup :verify_on_exit!

        test "fetches CRM records" do
          expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, headers, _opts ->
            assert url =~ "crm/v8/Leads"
            assert {"Authorization", "Zoho-oauthtoken token123"} in headers

            {:ok, %HTTPoison.Response{
              status_code: 200,
              body: Jason.encode!(%{"data" => [%{"id" => "123"}]})
            }}
          end)

          input = ZohoAPI.InputRequest.new("token123")
                  |> ZohoAPI.InputRequest.with_module_api_name("Leads")

          assert {:ok, result} = ZohoAPI.Modules.CRM.Records.get_records(input)
          assert result["data"] == [%{"id" => "123"}]
        end
      end

  ## Custom HTTP Client

  You can implement your own HTTP client by implementing this behaviour:

      defmodule MyApp.CustomHTTPClient do
        @behaviour ZohoAPI.HTTPClient

        @impl true
        def request(method, url, body, headers, options) do
          # Your custom implementation
          # Must return {:ok, %HTTPoison.Response{}} or {:error, %HTTPoison.Error{}}
        end
      end

      # In config
      config :zoho_api, :http_client, MyApp.CustomHTTPClient

  ## Timeout Configuration

  Default timeout is 30 seconds (30_000 ms). Configure globally:

      config :zoho_api, :http_timeout, 60_000  # 60 seconds

  Or per-request using `Request.with_timeout/2` (connection timeout)
  and `Request.with_recv_timeout/2` (receive timeout).
  """

  @doc """
  Performs an HTTP request.

  ## Parameters

    - `method` - HTTP method as an atom (:get, :post, :put, :patch, :delete)
    - `url` - The request URL
    - `body` - The request body (string)
    - `headers` - List of header tuples
    - `options` - HTTPoison options (timeout, recv_timeout, etc.)

  ## Returns

    - `{:ok, %HTTPoison.Response{}}` on success
    - `{:error, %HTTPoison.Error{}}` on failure
  """
  @callback request(
              method :: atom(),
              url :: String.t(),
              body :: String.t(),
              headers :: list(),
              options :: keyword()
            ) ::
              {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}

  @doc """
  Returns the configured HTTP client implementation.

  Defaults to HTTPoison if not configured.
  """
  @spec impl() :: module()
  def impl do
    Application.get_env(:zoho_api, :http_client, HTTPoison)
  end
end
