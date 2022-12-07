defmodule ZohoCrm.Modules.Projects do
  @moduledoc """
  This module handle Zoho Project API
  """

  alias ZohoCrm.Request
  alias ZohoCrm.InputRequest

  @api_type "portal"
  @project_base "https://projectsapi.zoho.in/restapi"

  @type portal_id() :: String.t()
  @type project_id() :: String.t()
  @type task_id() :: String.t()
  @type comment_id() :: String.t()

  @spec list_tasks(ZohoCrm.InputRequest.t(), portal_id(), project_id()) ::
          {:error, any} | {:ok, any}
  def list_tasks(%InputRequest{} = r, portal_id, project_id) do
    path = "/portal/#{portal_id}/projects/#{project_id}/tasks/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec get_task(ZohoCrm.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def get_task(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec create_task(ZohoCrm.InputRequest.t(), portal_id(), project_id()) ::
          {:error, any} | {:ok, any}
  def create_task(%InputRequest{} = r, portal_id, project_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec list_comments(ZohoCrm.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def list_comments(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:get)
    |> Request.with_body(r.body)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec add_comment(ZohoCrm.InputRequest.t(), portal_id(), project_id(), task_id()) ::
          {:error, any} | {:ok, any}
  def add_comment(%InputRequest{} = r, portal_id, project_id, task_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec update_comment(
          ZohoCrm.InputRequest.t(),
          portal_id(),
          project_id(),
          task_id(),
          comment_id()
        ) ::
          {:error, any} | {:ok, any}
  def update_comment(%InputRequest{} = r, portal_id, project_id, task_id, comment_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/#{comment_id}/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end

  @spec delete_comment(
          ZohoCrm.InputRequest.t(),
          portal_id(),
          project_id(),
          task_id(),
          comment_id()
        ) ::
          {:error, any} | {:ok, any}
  def delete_comment(%InputRequest{} = r, portal_id, project_id, task_id, comment_id) do
    path = "portal/#{portal_id}/projects/#{project_id}/tasks/#{task_id}/comments/#{comment_id}/"

    Request.new(@api_type)
    |> Request.set_base_url(@project_base)
    |> Request.with_path(path)
    |> Request.with_method(:delete)
    |> Request.with_body(r.body)
    |> Request.with_params(r.query_params)
    |> Request.set_headers(r.access_token)
    |> Request.send()
  end
end
