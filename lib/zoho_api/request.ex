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
    - `"recruit_bulk"` - Zoho Recruit Bulk API (v2)
    - `"composite"` - Zoho CRM Composite API (v8)

  ## Examples

      Request.new("crm")
      |> Request.set_access_token("token123")
      |> Request.with_method(:get)
      |> Request.with_path("Leads")
      |> Request.send()
  """

  require Logger

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

  **Note:** Timeout values must be positive integers (> 0). Invalid values
  will raise an `ArgumentError` with a descriptive message.

  ## Recommended Timeout Values

  | Operation Type     | Connection | Receive    |
  |--------------------|------------|------------|
  | Standard API calls | 30s        | 30s        |
  | Search operations  | 30s        | 60s        |
  | Bulk read/write    | 60s        | 120-300s   |
  | File uploads       | 60s        | 120s+      |
  | Large exports      | 60s        | 300-600s   |

  ## Timeout Fallback Precedence

  The actual timeout used depends on what you set:

  | You Set                      | Connection Timeout    | Receive Timeout       |
  |------------------------------|----------------------|----------------------|
  | Neither                      | Global config/30s    | Global config/30s    |
  | `timeout` only               | Your timeout         | Your timeout         |
  | `recv_timeout` only          | Global config/30s    | Your recv_timeout    |
  | Both                         | Your timeout         | Your recv_timeout    |

  Global config: `config :zoho_api, :http_timeout, 45_000`

  ## Examples

      # Set 1 minute connection timeout
      Request.new("bulk")
      |> Request.with_timeout(60_000)
  """
  @spec with_timeout(t(), pos_integer()) :: t()
  def with_timeout(%__MODULE__{} = r, timeout) when is_integer(timeout) and timeout > 0 do
    %{r | timeout: timeout}
  end

  def with_timeout(%__MODULE__{}, timeout) do
    raise ArgumentError,
          "timeout must be a positive integer, got: #{inspect(timeout)}"
  end

  @doc """
  Sets the receive timeout in milliseconds.

  This is the timeout for receiving data from the server after the
  connection is established. Default is 30 seconds (30_000 ms).

  For bulk operations that return large amounts of data, increase this value.
  See also `with_timeout/2` for connection timeout.

  **Note:** Timeout values must be positive integers (> 0). Invalid values
  will raise an `ArgumentError` with a descriptive message.

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

  def with_recv_timeout(%__MODULE__{}, timeout) do
    raise ArgumentError,
          "recv_timeout must be a positive integer, got: #{inspect(timeout)}"
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

    case send_raw(r) do
      {:ok, status_code, body} when status_code in 200..299 ->
        {:ok, body}

      {:ok, status_code, body} ->
        log_error(r.method, url, status_code, body)
        {:error, body}

      {:error, reason} ->
        Logger.error(
          "[ZohoAPI] #{r.method |> to_string() |> String.upcase()} #{url} - Network error: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Sends the HTTP request and returns the raw response with status code.

  This is useful for retry logic and token refresh handling where you need
  to inspect the HTTP status code before deciding how to proceed.

  ## Returns

    - `{:ok, status_code, body}` on HTTP response (any status code)
    - `{:error, reason}` on connection/network error

  ## Examples

      case Request.send_raw(request) do
        {:ok, 200, body} -> {:ok, body}
        {:ok, 401, _body} -> refresh_token_and_retry()
        {:ok, 500, body} -> {:error, {:server_error, body}}
        {:error, :timeout} -> {:error, :timeout}
      end
  """
  @spec send_raw(t()) :: {:ok, integer(), any()} | {:error, any()}
  def send_raw(%__MODULE__{} = r) do
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
        |> handle_raw_response()

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

  defp handle_raw_response({:ok, %HTTPoison.Response{body: body, status_code: status_code}}) do
    {:ok, status_code, json_or_value(body)}
  end

  defp handle_raw_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
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

  # CRM Bulk API (Bulk Read/Write)
  def construct_url(%__MODULE__{api_type: "bulk"} = r) do
    base_url = get_region_url(:zohoapis, r.region)
    base = "#{base_url}/crm/bulk/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Recruit Bulk API (Bulk Read/Write)
  # URL pattern: https://recruit.zoho.{region}/recruit/bulk/v2/{path}
  def construct_url(%__MODULE__{api_type: "recruit_bulk"} = r) do
    base_url = get_region_url(:recruit, r.region)
    base = "#{base_url}/recruit/bulk/#{r.version}/#{r.path}"
    append_params(base, r.params)
  end

  # Composite API
  # Note: The `path` field is intentionally ignored for composite requests.
  # The endpoint is always `/__composite_requests` - individual request paths
  # are specified in the request body's `url` field for each sub-request.
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

  # Log API errors with helpful context
  defp log_error(method, url, status_code, body) when is_map(body) do
    error_code = body["code"] || body["errorCode"] || "UNKNOWN"
    message = body["message"] || "No message provided"

    # For generic INVALID_REQUEST errors, try to diagnose the real cause
    {diagnosed_code, diagnosed_hint} =
      if error_code == "INVALID_REQUEST" and map_size(body["details"] || %{}) == 0 do
        diagnose_invalid_request(url)
      else
        {error_code, error_hint(error_code)}
      end

    Logger.error("""
    [ZohoAPI] #{method |> to_string() |> String.upcase()} #{url}
      Status: #{status_code}
      Error: #{diagnosed_code}
      Message: #{message}#{diagnosed_hint}
    """)
  end

  defp log_error(method, url, status_code, body) do
    Logger.error(
      "[ZohoAPI] #{method |> to_string() |> String.upcase()} #{url} - Status: #{status_code}, Body: #{inspect(body)}"
    )
  end

  # Provide helpful hints for common Zoho error codes
  defp error_hint("OAUTH_SCOPE_MISMATCH"),
    do:
      "\n      Hint: Your OAuth token lacks required scopes. Regenerate refresh token with proper scopes (e.g., ZohoCRM.modules.ALL)"

  defp error_hint("SCOPE_MISMATCH"),
    do:
      "\n      Hint: Your OAuth token lacks required scopes. Regenerate refresh token with proper scopes"

  defp error_hint("INVALID_TOKEN"),
    do: "\n      Hint: Access token is invalid or expired. Try refreshing the token"

  defp error_hint("AUTHENTICATION_FAILURE"),
    do: "\n      Hint: Authentication failed. Check your access token and credentials"

  defp error_hint("INVALID_REQUEST"),
    do:
      "\n      Hint: Request rejected. Common causes: wrong API version, missing scopes, or invalid endpoint"

  defp error_hint("INVALID_DATA"),
    do: "\n      Hint: Request body contains invalid data. Check field names and values"

  defp error_hint("MANDATORY_NOT_FOUND"),
    do: "\n      Hint: Required field is missing from the request body"

  defp error_hint("INVALID_MODULE"),
    do:
      "\n      Hint: Module name is invalid. Check spelling (e.g., 'Leads', 'Contacts', 'Deals')"

  defp error_hint("NO_PERMISSION"),
    do: "\n      Hint: User lacks permission for this operation. Check Zoho CRM profile settings"

  defp error_hint("RECORD_NOT_FOUND" <> _),
    do: "\n      Hint: The requested record does not exist or was deleted"

  defp error_hint(_), do: ""

  # Diagnose generic INVALID_REQUEST errors by probing a diagnostic endpoint
  # Zoho's /org endpoint returns more specific errors like OAUTH_SCOPE_MISMATCH
  defp diagnose_invalid_request(url) do
    # Extract base URL and check if it's a CRM request
    uri = URI.parse(url)

    cond do
      String.contains?(uri.path || "", "/crm/") ->
        # It's a CRM request - the most common cause is missing scopes
        {"INVALID_REQUEST (likely OAUTH_SCOPE_MISMATCH)",
         """

               Hint: This generic error usually means your OAuth token lacks CRM scopes.
               To fix: Regenerate your refresh token with proper scopes:
                 1. Go to https://api-console.zoho.in (or .com for US)
                 2. Generate code with scopes: ZohoCRM.modules.ALL,ZohoCRM.settings.ALL,ZohoCRM.users.ALL
                 3. Exchange code for new refresh token
         """}

      String.contains?(uri.path || "", "/desk/") or String.contains?(uri.host || "", "desk.") ->
        {"INVALID_REQUEST (likely SCOPE_MISMATCH)",
         """

               Hint: This generic error usually means your OAuth token lacks Desk scopes.
               To fix: Regenerate your refresh token with Desk scopes (e.g., Desk.tickets.ALL)
         """}

      true ->
        {"INVALID_REQUEST", error_hint("INVALID_REQUEST")}
    end
  end
end
