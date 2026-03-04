defmodule ZohoAPI.HTTPClient.Req do
  @moduledoc """
  Default HTTP client implementation using Req.
  """

  @behaviour ZohoAPI.HTTPClient

  @impl true
  def request(method, url, body, headers, options) do
    receive_timeout = Keyword.get(options, :receive_timeout, 30_000)
    connect_timeout = Keyword.get(options, :connect_timeout, 30_000)

    req_options = [
      method: method,
      url: url,
      body: body,
      headers: headers,
      receive_timeout: receive_timeout,
      connect_options: [timeout: connect_timeout],
      decode_body: false,
      retry: false
    ]

    case Req.request(req_options) do
      {:ok, response} -> {:ok, response}
      {:error, exception} -> {:error, exception}
    end
  end
end
