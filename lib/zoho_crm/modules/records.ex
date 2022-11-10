defmodule ZohoCrm.Modules.Records do
  @moduledoc """
  This module handle Zoho CRM Records API
  """

  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  def get_records(%InputRequest{} = r) do
    Request.new()
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end
end
