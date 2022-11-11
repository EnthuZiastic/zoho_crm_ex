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
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def insert_records(%InputRequest{} = r) do
    Request.new()
    |> Request.with_method(:post)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.set_headers(r.access_token)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  def update_records(%InputRequest{} = r) do
    Request.new()
    |> Request.with_method(:put)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.set_headers(r.access_token)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  def search_records(%InputRequest{} = r) do
    Request.new()
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.set_headers(r.access_token)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end
end
