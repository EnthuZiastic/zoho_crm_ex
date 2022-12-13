defmodule ZohoCrm.Modules.Recruit.Records do
  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  @api_type "recruit"
  @version "v2"

  def get_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def insert_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.with_path("#{r.module_api_name}")
    |> Request.with_method(:post)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  def update_recruit_records(%InputRequest{} = r) do
    Request.new(@api_type)
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
    |> Request.with_version(@version)
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.set_headers(r.access_token)
    |> Request.with_params(r.query_params)
    |> Request.with_body(%{"data" => r.body})
    |> Request.send()
  end
end
