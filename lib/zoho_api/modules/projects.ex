defmodule ZohoAPI.Modules.Projects do
  @moduledoc """
  This module handle Zoho Project API
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @api_type "portal"
  @project_base "https://projectsapi.zoho.in/restapi"

  @type portal_id() :: String.t()
  @type project_id() :: String.t()
  @type task_id() :: String.t()
  @type comment_id() :: String.t()

  @spec list_tasks(ZohoAPI.InputRequest.t(), portal_id(), project_id()) ::
          {:error, any} | {:ok, any}
  def list_tasks(%InputRequest{} = r, portal_id, project_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.send()
  end

  @spec get_task(ZohoAPI.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def get_task(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.send()
  end

  @spec create_task(ZohoAPI.InputRequest.t(), portal_id(), project_id()) ::
          {:error, any} | {:ok, any}
  def create_task(%InputRequest{} = r, portal_id, project_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec update_task(ZohoAPI.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def update_task(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec list_comments(ZohoAPI.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def list_comments(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec add_comment(ZohoAPI.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def add_comment(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec update_comment(
          ZohoAPI.InputRequest.t(),
          portal_id(),
          project_id(),
          task_id(),
          comment_id()
        ) ::
          {:error, any} | {:ok, any}
  def update_comment(%InputRequest{} = r, portal_id, project_id, task_id, comment_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/#{comment_id}/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec delete_comment(
          ZohoAPI.InputRequest.t(),
          portal_id(),
          project_id(),
          task_id(),
          comment_id()
        ) ::
          {:error, any} | {:ok, any}
  def delete_comment(%InputRequest{} = r, portal_id, project_id, task_id, comment_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/#{comment_id}/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:delete)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @spec list_users(InputRequest.t(), portal_id(), project_id()) ::
          {:error, [map()]} | {:ok, any}
  def list_users(%InputRequest{} = r, portal_id, project_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/users/"

    construct_request(r)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.set_access_token(ir.access_token)
    |> Request.with_params(ir.query_params)
  end
end
