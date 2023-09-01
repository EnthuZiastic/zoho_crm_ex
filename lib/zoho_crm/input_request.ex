defmodule ZohoCrm.InputRequest do
  @moduledoc """
  Api input request data structure
  """

  @enforce_keys [:access_token]
  defstruct [:module_api_name, :body, :query_params, :access_token]

  @type access_token :: String.t()
  @type module_api_name :: String.t() | nil
  @type query_params :: map()
  @type body :: map()

  @type t() :: %__MODULE__{
          access_token: String.t(),
          module_api_name: module_api_name(),
          query_params: map(),
          body: map()
        }

  @spec new(access_token, module_api_name, query_params, body) :: t()
  def new(access_token, module_api_name \\ nil, query_params \\ %{}, body \\ %{}) do
    %__MODULE__{
      access_token: access_token,
      body: body,
      module_api_name: module_api_name,
      query_params: query_params
    }
  end

  def with_module_api_name(%__MODULE__{} = ir, module_api_name \\ nil) do
    %{ir | module_api_name: module_api_name}
  end

  def with_access_token(%__MODULE__{} = ir, access_token) when is_binary(access_token) do
    %{ir | access_token: access_token}
  end

  def with_query_params(%__MODULE__{} = ir, query_params \\ %{}) when is_map(query_params) do
    %{ir | query_params: query_params}
  end

  def with_body(%__MODULE__{} = ir, body \\ %{}) when is_map(body) do
    %{ir | body: body}
  end
end
