defmodule ZohoAPI.Projects do
  @moduledoc """
  High-level Zoho Projects client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  portal_id and project_id directly — no token handling required.

  ## Examples

      {:ok, result} = ZohoAPI.Projects.create_task("portal_id", "project_id", %{name: "New Task"})
      {:ok, result} = ZohoAPI.Projects.add_comment("portal_id", "project_id", "task_id", %{content: "comment"})
      {:ok, users}  = ZohoAPI.Projects.list_users("portal_id", "project_id")
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Projects, as: ProjectsAPI
  alias ZohoAPI.TokenCache

  @type portal_id :: String.t()
  @type project_id :: String.t()
  @type task_id :: String.t()
  @type comment_id :: String.t()

  @spec list_tasks(portal_id(), project_id(), map()) :: {:ok, map()} | {:error, any()}
  def list_tasks(portal_id, project_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, params)
      |> ProjectsAPI.list_tasks(portal_id, project_id)
    end
  end

  @spec get_task(portal_id(), project_id(), task_id(), map()) :: {:ok, map()} | {:error, any()}
  def get_task(portal_id, project_id, task_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, params)
      |> ProjectsAPI.get_task(portal_id, project_id, task_id)
    end
  end

  @spec create_task(portal_id(), project_id(), map()) :: {:ok, map()} | {:error, any()}
  def create_task(portal_id, project_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, %{}, attrs)
      |> ProjectsAPI.create_task(portal_id, project_id)
    end
  end

  @spec update_task(portal_id(), project_id(), task_id(), map()) :: {:ok, map()} | {:error, any()}
  def update_task(portal_id, project_id, task_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, %{}, attrs)
      |> ProjectsAPI.update_task(portal_id, project_id, task_id)
    end
  end

  @spec list_comments(portal_id(), project_id(), task_id(), map()) ::
          {:ok, map()} | {:error, any()}
  def list_comments(portal_id, project_id, task_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, params)
      |> ProjectsAPI.list_comments(portal_id, project_id, task_id)
    end
  end

  @spec add_comment(portal_id(), project_id(), task_id(), map()) ::
          {:ok, map()} | {:error, any()}
  def add_comment(portal_id, project_id, task_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, %{}, attrs)
      |> ProjectsAPI.add_comment(portal_id, project_id, task_id)
    end
  end

  @spec list_users(portal_id(), project_id()) :: {:ok, map()} | {:error, any()}
  def list_users(portal_id, project_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:project) do
      token
      |> InputRequest.new(nil, %{})
      |> ProjectsAPI.list_users(portal_id, project_id)
    end
  end
end
