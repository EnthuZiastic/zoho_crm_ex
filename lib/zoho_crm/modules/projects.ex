defmodule ZohoCrm.Modules.Projects do
  @moduledoc """
  This module handle Zoho Project API
  """

  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  @api_type "portal"
  @project_base "https://projectsapi.zoho.in"

  @type portal_id() :: String.t()
  @type project_id() :: String.t()

  @spec list_tasks(ZohoCrm.InputRequest.t(), portal_id(), project_id()) ::
          {:error, any} | {:ok, any}
  def list_tasks(%InputRequest{} = r, portal_id, project_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end
end
