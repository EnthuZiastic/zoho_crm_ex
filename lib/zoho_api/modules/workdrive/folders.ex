defmodule ZohoAPI.Modules.WorkDrive.Folders do
  @moduledoc """
  Zoho WorkDrive Folders API.

  This module handles folder operations for Zoho WorkDrive cloud storage.

  ## Features

    - List team folders
    - List folders within a parent folder
    - Get folder details
    - Create new folders
    - Delete folders

  ## Examples

      # List team folders
      input = InputRequest.new("access_token")
      {:ok, folders} = Folders.list_team_folders(input, "team_123")

      # Create a new folder
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "data" => %{
          "attributes" => %{
            "name" => "My Folder",
            "parent_id" => "parent_folder_id"
          },
          "type" => "files"
        }
      })

      {:ok, folder} = Folders.create_folder(input)
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @doc """
  Lists all team folders for a team.

  ## Parameters

    - `input` - InputRequest with access token
    - `team_id` - The team ID

  ## Returns

    - `{:ok, %{"data" => [folders]}}` on success
  """
  @spec list_team_folders(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def list_team_folders(%InputRequest{} = r, team_id) do
    construct_request(r)
    |> Request.with_path("teams/#{team_id}/teamfolders")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Lists folders and files within a parent folder.

  ## Parameters

    - `input` - InputRequest with access token
    - `folder_id` - The parent folder ID
  """
  @spec list_folders(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def list_folders(%InputRequest{} = r, folder_id) do
    construct_request(r)
    |> Request.with_path("files/#{folder_id}/files")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Gets details of a specific folder.

  ## Parameters

    - `input` - InputRequest with access token
    - `folder_id` - The folder ID
  """
  @spec get_folder(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_folder(%InputRequest{} = r, folder_id) do
    construct_request(r)
    |> Request.with_path("files/#{folder_id}")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Creates a new folder.

  ## Parameters

    - `input` - InputRequest with `body` containing:
      - `data.attributes.name` - Folder name
      - `data.attributes.parent_id` - Parent folder ID
      - `data.type` - Must be "files"

  ## Body Format

      %{
        "data" => %{
          "attributes" => %{
            "name" => "New Folder",
            "parent_id" => "parent_folder_id"
          },
          "type" => "files"
        }
      }
  """
  @spec create_folder(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def create_folder(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("files")
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Deletes a folder.

  ## Parameters

    - `input` - InputRequest with access token
    - `folder_id` - The folder ID to delete
  """
  @spec delete_folder(InputRequest.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def delete_folder(%InputRequest{} = r, folder_id) do
    construct_request(r)
    |> Request.with_path("files/#{folder_id}")
    |> Request.with_method(:delete)
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new("workdrive")
    |> Request.with_version("v1")
    |> Request.set_access_token(ir.access_token)
    |> Request.with_params(ir.query_params)
  end
end
