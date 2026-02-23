defmodule ZohoAPI.InputRequest do
  @moduledoc """
  API input request data structure.

  This struct is used as the primary input for all Zoho API operations.
  It encapsulates the access token, module name, query parameters, body,
  org_id (required for Zoho Desk API), region, and optional features like
  token auto-refresh, retry options, and rate limiting.

  ## Examples

      # Basic usage
      input = InputRequest.new("access_token")

      # With module name
      input = InputRequest.new("access_token")
      |> InputRequest.with_module_api_name("Leads")

      # With body data
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{"Email" => "test@example.com"})

      # For Zoho Desk (requires org_id)
      input = InputRequest.new("access_token")
      |> InputRequest.with_org_id("org_123")

      # With specific region (default is :in for India)
      input = InputRequest.new("access_token")
      |> InputRequest.with_region(:eu)

      # With token auto-refresh on 401
      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("refresh_token")
      |> InputRequest.with_on_token_refresh(fn new_token ->
        MyApp.TokenStore.update(new_token)
      end)

      # With custom retry settings
      input = InputRequest.new("access_token")
      |> InputRequest.with_retry_opts(max_retries: 5, base_delay_ms: 2000)

      # With rate limiting options
      input = InputRequest.new("access_token")
      |> InputRequest.with_rate_limit_opts(key: "zoho:priority")
  """

  alias ZohoAPI.Regions

  @enforce_keys [:access_token]
  defstruct [
    :module_api_name,
    :body,
    :query_params,
    :access_token,
    :org_id,
    :refresh_token,
    :on_token_refresh,
    :retry_opts,
    :rate_limit_opts,
    region: :in
  ]

  @type access_token :: String.t()
  @type module_api_name :: String.t() | nil
  @type query_params :: map()
  @type body :: map() | list() | String.t() | {:form, list()}
  @type org_id :: String.t() | nil
  @type region :: :in | :com | :eu | :au | :jp | :uk | :ca | :sa
  @type token_refresh_callback :: (String.t() -> any()) | nil

  @type t() :: %__MODULE__{
          access_token: String.t(),
          module_api_name: module_api_name(),
          query_params: map(),
          body: body(),
          org_id: org_id(),
          region: region(),
          refresh_token: String.t() | nil,
          on_token_refresh: token_refresh_callback(),
          retry_opts: keyword() | nil,
          rate_limit_opts: keyword() | nil
        }

  @doc """
  Creates a new InputRequest struct.

  ## Parameters

    - `access_token` - The OAuth access token (required)
    - `module_api_name` - The Zoho module API name (optional)
    - `query_params` - URL query parameters (optional, default: %{})
    - `body` - Request body (optional, default: %{})

  ## Examples

      iex> InputRequest.new("token123")
      %InputRequest{access_token: "token123", ...}
  """
  @spec new(access_token, module_api_name, query_params, body) :: t()
  def new(access_token, module_api_name \\ nil, query_params \\ %{}, body \\ %{}) do
    %__MODULE__{
      access_token: access_token,
      body: body,
      module_api_name: module_api_name,
      query_params: query_params,
      org_id: nil,
      region: :in
    }
  end

  @doc """
  Sets the module API name.
  """
  @spec with_module_api_name(t(), String.t() | nil) :: t()
  def with_module_api_name(%__MODULE__{} = ir, module_api_name \\ nil) do
    %{ir | module_api_name: module_api_name}
  end

  @doc """
  Sets the access token.
  """
  @spec with_access_token(t(), String.t()) :: t()
  def with_access_token(%__MODULE__{} = ir, access_token) when is_binary(access_token) do
    %{ir | access_token: access_token}
  end

  @doc """
  Sets the query parameters.
  """
  @spec with_query_params(t(), map()) :: t()
  def with_query_params(%__MODULE__{} = ir, query_params \\ %{}) when is_map(query_params) do
    %{ir | query_params: query_params}
  end

  @doc """
  Sets the request body.

  The body can be a map or a list (for batch record operations).
  """
  @spec with_body(t(), map() | list() | String.t()) :: t()
  def with_body(%__MODULE__{} = ir, body \\ %{})
      when is_map(body) or is_list(body) or is_binary(body) do
    %{ir | body: body}
  end

  @doc """
  Sets the organization ID (required for Zoho Desk API).
  """
  @spec with_org_id(t(), String.t()) :: t()
  def with_org_id(%__MODULE__{} = ir, org_id) when is_binary(org_id) do
    %{ir | org_id: org_id}
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

      iex> InputRequest.new("token") |> InputRequest.with_region(:eu)
      %InputRequest{region: :eu, ...}

  Raises `ArgumentError` if an invalid region is provided.
  """
  @spec with_region(t(), region()) :: t()
  def with_region(%__MODULE__{} = ir, region) do
    Regions.validate!(region)
    %{ir | region: region}
  end

  @doc """
  Sets the refresh token for automatic token refresh on 401 responses.

  When a 401 (Unauthorized) response is received and a refresh token is set,
  the client will automatically call `Token.refresh_access_token/1` and retry
  the request with the new access token.

  ## Examples

      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("1000.abc123...")
  """
  @spec with_refresh_token(t(), String.t()) :: t()
  def with_refresh_token(%__MODULE__{} = ir, refresh_token) when is_binary(refresh_token) do
    %{ir | refresh_token: refresh_token}
  end

  @doc """
  Sets a callback function to be called when the access token is refreshed.

  This is useful for persisting the new token to your database or cache.
  The callback receives the new access token as its argument.

  ## Examples

      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("refresh_token")
      |> InputRequest.with_on_token_refresh(fn new_token ->
        MyApp.Repo.update!(token_record, %{access_token: new_token})
        Logger.info("Token refreshed")
      end)
  """
  @spec with_on_token_refresh(t(), (String.t() -> any())) :: t()
  def with_on_token_refresh(%__MODULE__{} = ir, callback) when is_function(callback, 1) do
    %{ir | on_token_refresh: callback}
  end

  @doc """
  Sets retry options for this specific request.

  Overrides the global retry configuration for this request only.

  ## Options

    - `:max_retries` - Maximum number of retry attempts (default: 3)
    - `:base_delay_ms` - Initial delay between retries in milliseconds (default: 1000)
    - `:max_delay_ms` - Maximum delay cap in milliseconds (default: 30000)
    - `:jitter` - Add random jitter to delay (default: true)

  ## Examples

      # More aggressive retries for critical operation
      input = InputRequest.new("token")
      |> InputRequest.with_retry_opts(max_retries: 5, base_delay_ms: 2000)

      # Disable retries
      input = InputRequest.new("token")
      |> InputRequest.with_retry_opts(max_retries: 0)
  """
  @spec with_retry_opts(t(), keyword()) :: t()
  def with_retry_opts(%__MODULE__{} = ir, opts) when is_list(opts) do
    %{ir | retry_opts: opts}
  end

  @doc """
  Sets rate limiting options for this specific request.

  Overrides the global rate limiter configuration for this request only.

  ## Options

    - `:enabled` - Enable/disable rate limiting (default from global config)
    - `:key` - Rate limit key/bucket (default: "zoho_api")
    - `:request_count` - Max requests per time window
    - `:time_window` - Time window in seconds

  ## Examples

      # Use different rate limit bucket for priority operations
      input = InputRequest.new("token")
      |> InputRequest.with_rate_limit_opts(key: "zoho:priority")

      # Disable rate limiting for this request
      input = InputRequest.new("token")
      |> InputRequest.with_rate_limit_opts(enabled: false)
  """
  @spec with_rate_limit_opts(t(), keyword()) :: t()
  def with_rate_limit_opts(%__MODULE__{} = ir, opts) when is_list(opts) do
    %{ir | rate_limit_opts: opts}
  end
end
