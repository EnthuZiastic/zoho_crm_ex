defmodule ZohoAPI.InputRequest do
  @moduledoc """
  API input request data structure.

  This struct is used as the primary input for all Zoho API operations.
  It encapsulates the access token, module name, query parameters, body,
  org_id (required for Zoho Desk API), and region.

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
  """

  alias ZohoAPI.Regions

  @enforce_keys [:access_token]
  defstruct [:module_api_name, :body, :query_params, :access_token, :org_id, region: :in]

  @type access_token :: String.t()
  @type module_api_name :: String.t() | nil
  @type query_params :: map()
  @type body :: map() | list() | String.t()
  @type org_id :: String.t() | nil
  @type region :: :in | :com | :eu | :au | :jp | :uk | :ca | :sa

  @type t() :: %__MODULE__{
          access_token: String.t(),
          module_api_name: module_api_name(),
          query_params: map(),
          body: body(),
          org_id: org_id(),
          region: region()
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
end
