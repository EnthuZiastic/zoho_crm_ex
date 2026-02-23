defmodule ZohoAPI.Projects do
  @moduledoc """
  High-level Zoho Projects client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  portal_id and project_id directly — no token handling required.

  Responses are trimmed: task IDs, user lists, etc. are extracted from the raw
  Zoho response wrapper and returned directly.

  ## Examples

      {:ok, task_id} = ZohoAPI.Projects.create_task("portal_id", "project_id", %{name: "New Task"})
      :ok            = ZohoAPI.Projects.add_comment("portal_id", "project_id", "task_id", %{content: "comment"})
      {:ok, users}   = ZohoAPI.Projects.list_users("portal_id", "project_id")
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Projects, as: ProjectsAPI
  alias ZohoAPI.TokenCache

  @type portal_id :: String.t()
  @type project_id :: String.t()
  @type task_id :: String.t()

  @spec list_tasks(portal_id(), project_id(), map()) :: {:ok, list(map())} | {:error, any()}
  def list_tasks(portal_id, project_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> ProjectsAPI.list_tasks(portal_id, project_id) do
      {:ok, Map.get(raw, "tasks", [])}
    end
  end

  @spec get_task(portal_id(), project_id(), task_id(), map()) ::
          {:ok, map()} | {:error, any()}
  def get_task(portal_id, project_id, task_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> ProjectsAPI.get_task(portal_id, project_id, task_id) do
      case raw do
        %{"tasks" => [task | _]} -> {:ok, task}
        other -> {:ok, other}
      end
    end
  end

  @spec create_task(portal_id(), project_id(), map()) :: {:ok, String.t()} | {:error, any()}
  def create_task(portal_id, project_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, attrs)
           |> ProjectsAPI.create_task(portal_id, project_id) do
      case raw do
        %{"tasks" => [%{"id" => task_id} | _]} -> {:ok, to_string(task_id)}
        other -> {:error, other}
      end
    end
  end

  @spec update_task(portal_id(), project_id(), task_id(), map()) ::
          {:ok, String.t()} | {:error, any()}
  def update_task(portal_id, project_id, task_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, attrs)
           |> ProjectsAPI.update_task(portal_id, project_id, task_id) do
      case raw do
        %{"tasks" => [%{"id" => id} | _]} -> {:ok, Integer.to_string(id)}
        other -> {:error, other}
      end
    end
  end

  @spec list_comments(portal_id(), project_id(), task_id(), map()) ::
          {:ok, list(map())} | {:error, any()}
  def list_comments(portal_id, project_id, task_id, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> ProjectsAPI.list_comments(portal_id, project_id, task_id) do
      {:ok, Map.get(raw, "comments", [])}
    end
  end

  @spec add_comment(portal_id(), project_id(), task_id(), map()) ::
          {:ok, map()} | {:error, any()}
  def add_comment(portal_id, project_id, task_id, attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects) do
      token
      |> InputRequest.new(nil, %{}, attrs)
      |> ProjectsAPI.add_comment(portal_id, project_id, task_id)
    end
  end

  @spec list_users(portal_id(), project_id()) :: {:ok, list(map())} | {:error, any()}
  def list_users(portal_id, project_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:projects),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{})
           |> ProjectsAPI.list_users(portal_id, project_id) do
      {:ok, Map.get(raw, "users", [])}
    end
  end
end
