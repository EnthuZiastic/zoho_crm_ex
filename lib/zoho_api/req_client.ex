defmodule ZohoAPI.ReqClient do
  @moduledoc """
  Default HTTP client implementation using the Req library.

  Implements the `ZohoAPI.HTTPClient` behaviour, wrapping `Req.request/1`
  and translating HTTPoison-style options (`:timeout`, `:recv_timeout`) to
  their Req equivalents.
  """

  @behaviour ZohoAPI.HTTPClient

  @impl true
  def request(method, url, body, headers, options) do
    connection_timeout = Keyword.get(options, :timeout, 30_000)
    receive_timeout = Keyword.get(options, :recv_timeout, connection_timeout)

    actual_body =
      case body do
        {:form, data} -> URI.encode_query(data)
        other -> other
      end

    Req.request(
      method: method,
      url: url,
      body: actual_body,
      headers: headers,
      decode_body: false,
      connect_options: [timeout: connection_timeout],
      receive_timeout: receive_timeout
    )
  end
end
