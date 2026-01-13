defmodule ZohoAPI.HTTPClient do
  @moduledoc """
  HTTP client behaviour for Zoho API requests.

  This module defines the behaviour for HTTP requests, allowing for
  easy mocking in tests using Mox.

  ## Usage

  In production, this uses HTTPoison directly. In tests, you can
  configure a mock implementation:

      # In test_helper.exs
      Mox.defmock(ZohoAPI.HTTPClientMock, for: ZohoAPI.HTTPClient)
      Application.put_env(:zoho_api, :http_client, ZohoAPI.HTTPClientMock)

  ## Configuration

      config :zoho_api, :http_client, ZohoAPI.HTTPClientMock

  ## Timeout Configuration

  Default timeout is 30 seconds. Configure globally:

      config :zoho_api, :http_timeout, 60_000

  Or per-request using `Request.with_timeout/2`.
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
