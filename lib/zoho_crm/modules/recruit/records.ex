defmodule ZohoCrm.Modules.Recruit.Records do
  @moduledoc """
  This module handle Zoho Recruit Records API
  """
  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  @api_type "recruit"
  @version "v2"
  @project_base "https://recruit.zoho.in"

  @type record_id :: String.t()

  def get_recruit_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.send()
  end

  def insert_recruit_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:post)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  def update_recruit_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:put)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  def search_recruit_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  @spec get_associated_records(InputRequest.t(), record_id) :: {:error, any} | {:ok, any}
  def get_associated_records(%InputRequest{} = r, record_id) do
    path = "#{r.module_api_name}/#{record_id}/associate"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.set_base_url(@project_base)
    |> Request.set_access_token(ir.access_token)
  end
end
