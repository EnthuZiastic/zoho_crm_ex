defmodule ZohoAPI.Request do
  @moduledoc """
  Handle HTTP requests to Zoho APIs.

  This module provides a builder pattern for constructing and sending
  HTTP requests to various Zoho API services.

  ## Supported API Types

    - `"crm"` - Zoho CRM API (v8)
    - `"desk"` - Zoho Desk API (v1)
    - `"workdrive"` - Zoho WorkDrive API (v1)
    - `"recruit"` - Zoho Recruit API (v2)
    - `"bookings"` - Zoho Bookings API (v1)
    - `"oauth"` - Zoho OAuth API (v2)
    - `"portal"` - Zoho Projects API
    - `"bulk"` - Zoho CRM Bulk API (v8)
    - `"composite"` - Zoho CRM Composite API (v8)

  ## Examples

      Request.new("crm")
      |> Request.set_access_token("token123")
      |> Request.with_method(:get)
      |> Request.with_path("Leads")
      |> Request.send()
  """

  alias ZohoAPI.HTTPClient
  alias ZohoAPI.Regions

  @base_url "https://www.zohoapis.in"
  @version "v8"

  @default_headers %{
    "Content-Type" => "application/json"
  }

  # Default timeout in milliseconds (30 seconds)
  @default_timeout 30_000

  @enforce_keys [:api_type]
  defstruct [
    :path,
    :method,
    :api_type,
    :timeout,
    :recv_timeout,
    params: %{},
    body: %{},
    headers: @default_headers,
    base_url: @base_url,
    version: @version,
    region: :in
  ]

  @type region :: :in | :com | :eu | :au | :jp | :uk | :ca | :sa

  @type t :: %__MODULE__{
          path: String.t() | nil,
          method: atom() | nil,
          api_type: String.t(),
          params: map(),
          body: map() | String.t(),
          headers: map(),
          base_url: String.t(),
          version: String.t(),
          region: region(),
          timeout: non_neg_integer() | nil,
          recv_timeout: non_neg_integer() | nil
        }

  @doc """
  Creates a new Request struct.

  ## Parameters

    - `api_type` - The API type (default: "crm")

  ## Examples

      iex> Request.new()
      %Request{api_type: "crm", ...}

      iex> Request.new("desk")
      %Request{api_type: "desk", ...}
  """
  @spec new(String.t()) :: t()
  def new(api_type \\ "crm") do
    %__MODULE__{api_type: api_type}
  end

  @doc """
  Sets the API type.
  """
  @spec set_api_type(t(), String.t()) :: t()
  def set_api_type(%__MODULE__{} = r, api_type) do
    %{r | api_type: api_type}
  end

  @doc """
  Sets the API version.
  """
  @spec with_version(t(), String.t()) :: t()
  def with_version(%__MODULE__{} = r, version) do
    %{r | version: version}
  end

  @doc """
  Sets the Zoho region.

  ## Supported Regions

    - `:in` - India (default)
    - `:com` - United States
    - `:eu` - Europe
    - `:au` - Australia
    - `:jp` - Japan
    - `:uk` - United Kingdom
    - `:ca` - Canada
    - `:sa` - Saudi Arabia

  ## Examples

      iex> Request.new() |> Request.with_region(:eu)
      %Request{region: :eu, ...}

  Raises `ArgumentError` if an invalid region is provided.
  """
  @spec with_region(t(), region()) :: t()
  def with_region(%__MODULE__{} = r, region) do
    # Validates region and raises ArgumentError with helpful message if invalid
    Regions.validate!(region)
    %{r | region: region}
  end

  @doc """
  Sets the HTTP method.
  """
  @spec with_method(t(), atom()) :: t()
  def with_method(%__MODULE__{} = r, method) do
    %{r | method: method}
  end

  @doc """
  Sets the base URL.
  """
  @spec set_base_url(t(), String.t()) :: t()
  def set_base_url(%__MODULE__{} = r, base_url) do
    %{r | base_url: base_url}
  end

  @doc """
  Merges additional headers into the request.
  """
  @spec set_headers(t(), map()) :: t()
  def set_headers(%__MODULE__{} = r, headers) when is_map(headers) do
    %{r | headers: Map.merge(r.headers, headers)}
  end

  @doc """
  Sets the OAuth access token header.
  """
  @spec set_access_token(t(), String.t()) :: t()
  def set_access_token(%__MODULE__{} = r, access_token) do
    token = %{
      "Authorization" => "Zoho-oauthtoken #{access_token}"
    }

    %{r | headers: Map.merge(r.headers, token)}
  end

  @doc """
  Sets the organization ID header (required for Zoho Desk).
  """
  @spec set_org_id(t(), String.t()) :: t()
  def set_org_id(%__MODULE__{} = r, org_id) do
    %{r | headers: Map.merge(r.headers, %{"orgId" => org_id})}
  end

  @doc """
  Sets the request path.
  """
  @spec with_path(t(), String.t()) :: t()
  def with_path(%__MODULE__{} = r, path) do
    %{r | path: path}
  end

  @doc """
  Sets the request body.
  """
  @spec with_body(t(), map() | String.t()) :: t()
  def with_body(%__MODULE__{} = r, body) do
    %{r | body: body}
  end

  @doc """
  Sets the URL query parameters.
  """
  @spec with_params(t(), map()) :: t()
  def with_params(%__MODULE__{} = r, params) do
    %{r | params: params}
  end

  @doc """
  Sets the connection timeout in milliseconds.

  This is the timeout for establishing the initial TCP connection.
  Default is 30 seconds (30_000 ms).

  For bulk operations that may take longer to connect, increase this value.
  See also `with_recv_timeout/2` for response timeout.

  **Note:** Timeout values must be positive integers (> 0). The guard clause
  ensures this, so passing 0 or negative values will raise a FunctionClauseError.

  ## Examples

      # Set 1 minute connection timeout
      Request.new("bulk")
      |> Request.with_timeout(60_000)
  """
  @spec with_timeout(t(), pos_integer()) :: t()
  def with_timeout(%__MODULE__{} = r, timeout) when is_integer(timeout) and timeout > 0 do
    %{r | timeout: timeout}
  end

  @doc """
  Sets the receive timeout in milliseconds.

  This is the timeout for receiving data from the server after the
  connection is established. Default is 30 seconds (30_000 ms).

  For bulk operations that return large amounts of data, increase this value.
  See also `with_timeout/2` for connection timeout.

  **Note:** Timeout values must be positive integers (> 0). The guard clause
  ensures this, so passing 0 or negative values will raise a FunctionClauseError.

  ## Examples

      # Set 5 minute receive timeout for bulk downloads
      Request.new("bulk")
      |> Request.with_recv_timeout(300_000)

      # Set both timeouts for comprehensive control
      Request.new("bulk")
      |> Request.with_timeout(60_000)
      |> Request.with_recv_timeout(300_000)
  """
  @spec with_recv_timeout(t(), pos_integer()) :: t()
  def with_recv_timeout(%__MODULE__{} = r, timeout) when is_integer(timeout) and timeout > 0 do
    %{r | recv_timeout: timeout}
  end

  @doc """
  Sends the HTTP request.

  ## Returns

    - `{:ok, response}` on success (2xx status codes)
    - `{:error, reason}` on failure
  """
  @spec send(t()) :: {:ok, any()} | {:error, any()}
  def send(%__MODULE__{} = r) do
    url = construct_url(r)
    headers = Map.to_list(r.headers)

    # Get default timeout from config, fallback to module default
    default_timeout = Application.get_env(:zoho_api, :http_timeout, @default_timeout)

    # Connection timeout (for establishing TCP connection)
    connection_timeout = r.timeout || default_timeout

    # Receive timeout (for receiving response data)
    receive_timeout = r.recv_timeout || r.timeout || default_timeout

    options = [timeout: connection_timeout, recv_timeout: receive_timeout]

    case encode_body(r.body) do
      {:ok, body} ->
        HTTPClient.impl().request(r.method, url, body, headers, options)
        |> handle_response()

      {:error, _} = error ->
        error
    end
  end

  defp encode_body(body) when is_map(body) do
    case Jason.encode(body) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, reason} -> {:error, "Failed to encode request body: #{inspect(reason)}"}
    end
  end

  defp encode_body(body) when is_list(body) do
    case Jason.encode(body) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, reason} -> {:error, "Failed to encode request body: #{inspect(reason)}"}
    end
  end

  defp encode_body(body) when is_binary(body), do: {:ok, body}
  defp encode_body(nil), do: {:ok, ""}
  defp encode_body(body), do: {:ok, to_string(body)}

  defp handle_response({:ok, %HTTPoison.Response{body: body, status_code: status_code}})
       when status_code in 200..299 do
    {:ok, json_or_value(body)}
  end

  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    {:error, json_or_value(body)}
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, json_or_value(reason)}
  end

  defp json_or_value(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed_value} -> parsed_value
      _ -> data
    end
  end

  defp json_or_value(data), do: data

  # CRM API
  @doc false
  def construct_url(%__MODULE__{api_type: "crm"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/crm/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Recruit API
  def construct_url(%__MODULE__{api_type: "recruit"} = r) do
    base_url = get_region_url(:recruit, r.region)
    base = "#{base_url}/recruit/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Bookings API
  def construct_url(%__MODULE__{api_type: "bookings"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/bookings/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # OAuth API (uses base_url which can be overridden by Token module)
  def construct_url(%__MODULE__{api_type: "oauth"} = r) do
    base = "#{r.base_url}/oauth/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Projects/Portal API
  def construct_url(%__MODULE__{api_type: "portal"} = r) do
    base_url = get_region_url(:projects, r.region)
    base = "#{base_url}#{r.path}"
    append_params(base, r.params)
  end

  # Desk API
  def construct_url(%__MODULE__{api_type: "desk"} = r) do
    base_url = get_region_url(:desk, r.region)
    base = "#{base_url}/api/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # WorkDrive API
  def construct_url(%__MODULE__{api_type: "workdrive"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/workdrive/api/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Bulk API (Bulk Read/Write)
  def construct_url(%__MODULE__{api_type: "bulk"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/crm/bulk/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Composite API
  def construct_url(%__MODULE__{api_type: "composite"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/crm/#{r.version}/__composite_requests"
    append_params(base, r.params)
  end

  defp get_region_url(service, region) do
    Regions.api_url(service, region)
  end

  defp append_params(base, params) when map_size(params) == 0, do: base

  defp append_params(base, params) do
    encoded_params = URI.encode_query(params)
    separator = if String.contains?(base, "?"), do: "&", else: "?"
    "#{base}#{separator}#{encoded_params}"
  end
end
