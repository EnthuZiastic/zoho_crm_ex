defmodule ZohoCrm.InputRequest do
  @moduledoc """
  Api input request data structure
  """
  defstruct [:module_api_name, :body, :query_params, :access_token]

  @enforce_keys [:access_token]
  @type access_token :: String.t()
  @type module_api_name :: String.t()

  @type t() :: %__MODULE__{
          access_token: String.t(),
          module_api_name: String.t() | nil,
          query_params: map(),
          body: map()
        }

  @spec new(access_token, module_api_name, map(), map()) :: t()
  def new(access_token, module_api_name \\ nil, query_params \\ %{}, body \\ %{}) do
    %__MODULE__{
      access_token: access_token,
      body: body,
      module_api_name: module_api_name,
      query_params: query_params
    }
  end
end
