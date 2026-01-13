defmodule ZohoAPI.InputRequest do
  @moduledoc """
  API input request data structure.

  This struct is used as the primary input for all Zoho API operations.
  It encapsulates the access token, module name, query parameters, body,
  and org_id (required for Zoho Desk API).

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
  """

  @enforce_keys [:access_token]
  defstruct [:module_api_name, :body, :query_params, :access_token, :org_id]

  @type access_token :: String.t()
  @type module_api_name :: String.t() | nil
  @type query_params :: map()
  @type body :: map() | list() | String.t()
  @type org_id :: String.t() | nil

  @type t() :: %__MODULE__{
          access_token: String.t(),
          module_api_name: module_api_name(),
          query_params: map(),
          body: body(),
          org_id: org_id()
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
      org_id: nil
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
end
