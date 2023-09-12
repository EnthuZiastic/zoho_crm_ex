defmodule ZohoCrm.Modules.Records do
  @moduledoc """
  This module handle Zoho CRM Records API
  """

  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  def get_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:get)
    |> Request.send()
  end

  def insert_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.send()
  end

  def update_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:put)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.send()
  end

  def search_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.send()
  end

  def delete_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:delete)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new()
    |> Request.set_access_token(ir.access_token)
    |> Request.with_params(ir.query_params)
    |> Request.with_body(%{"data" => ir.body})
  end
end
