defmodule ZohoCrm.Modules.Recruit.Records do
  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  @api_type "recruit"
  @version "v2"
  @project_base "https://recruit.zoho.in"

  @type record_id :: String.t()

  def get_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.set_base_url(@project_base)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def insert_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_version(@version)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:post)
    |> Request.with_body(%{"data" => r.body})
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def update_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_version(@version)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:post)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def search_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_version(@version)
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.set_headers(r.access_token)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end

  @spec get_associated_records(InputRequest.t(), record_id) :: {:error, any} | {:ok, any}
  def get_associated_records(%InputRequest{} = ir, record_id) do
    path = "#{ir.module_api_name}/#{record_id}/associate"

    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.set_headers(ir.access_token)
    |> Request.send()
  end
end
