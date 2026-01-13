defmodule ZohoCrm.Modules.WorkDrive.Files do
  @moduledoc """
  Zoho WorkDrive Files API.

  This module handles file operations for Zoho WorkDrive cloud storage.

  ## Features

    - List files in a folder
    - Get file details
    - Download files
    - Upload files
    - Rename, move, copy files
    - Delete files
    - Search files

  ## Examples

      # List files in a folder
      input = InputRequest.new("access_token")
      {:ok, files} = Files.list_files(input, "folder_123")

      # Download a file
      input = InputRequest.new("access_token")
      {:ok, content} = Files.download_file(input, "file_123")

      # Search for files
      input = InputRequest.new("access_token")
      |> InputRequest.with_query_params(%{search_string: "report"})

      {:ok, results} = Files.search_files(input)
  """

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Request

  @mime_types %{
    ".pdf" => "application/pdf",
    ".doc" => "application/msword",
    ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls" => "application/vnd.ms-excel",
    ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt" => "application/vnd.ms-powerpoint",
    ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".txt" => "text/plain",
    ".csv" => "text/csv",
    ".json" => "application/json",
    ".xml" => "application/xml",
    ".html" => "text/html",
    ".htm" => "text/html",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".bmp" => "image/bmp",
    ".svg" => "image/svg+xml",
    ".zip" => "application/zip",
    ".tar" => "application/x-tar",
    ".gz" => "application/gzip",
    ".rar" => "application/vnd.rar",
    ".7z" => "application/x-7z-compressed",
    ".mp3" => "audio/mpeg",
    ".mp4" => "video/mp4",
    ".avi" => "video/x-msvideo",
    ".mov" => "video/quicktime"
  }

  @doc """
  Lists files in a folder.

  ## Parameters

    - `input` - InputRequest with access token
    - `folder_id` - The folder ID
  """
  @spec list_files(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def list_files(%InputRequest{} = r, folder_id) do
    construct_request(r)
    |> Request.with_path("files/#{folder_id}/files")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Gets details of a specific file.

  ## Parameters

    - `input` - InputRequest with access token
    - `file_id` - The file ID
  """
  @spec get_file(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("files/#{file_id}")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Downloads a file's content.

  ## Parameters

    - `input` - InputRequest with access token
    - `file_id` - The file ID

  ## Returns

    - `{:ok, binary_content}` on success
  """
  @spec download_file(InputRequest.t(), String.t()) :: {:ok, binary()} | {:error, any()}
  def download_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("download/#{file_id}")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Uploads a file to a folder.

  ## Parameters

    - `input` - InputRequest with `body` containing the file content
    - `folder_id` - The destination folder ID
    - `file_name` - Name for the uploaded file

  ## Returns

    - `{:ok, file_metadata}` on success
  """
  @spec upload_file(InputRequest.t(), String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def upload_file(%InputRequest{} = r, folder_id, file_name) do
    content_type = mime_type(file_name)

    Request.new("workdrive")
    |> Request.with_version("v1")
    |> Request.set_access_token(r.access_token)
    |> Request.with_path("upload")
    |> Request.with_params(%{parent_id: folder_id, filename: file_name})
    |> Request.set_headers(%{"Content-Type" => content_type})
    |> Request.with_body(r.body)
    |> Request.with_method(:post)
    |> Request.send()
  end

  @doc """
  Renames a file.

  ## Parameters

    - `input` - InputRequest with `body` containing new name
    - `file_id` - The file ID

  ## Body Format

      %{
        "data" => %{
          "attributes" => %{"name" => "new_name.pdf"},
          "type" => "files"
        }
      }
  """
  @spec rename_file(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def rename_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("files/#{file_id}")
    |> Request.with_method(:patch)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Moves a file to another folder.

  ## Parameters

    - `input` - InputRequest with `body` containing new parent_id
    - `file_id` - The file ID

  ## Body Format

      %{
        "data" => %{
          "attributes" => %{"parent_id" => "new_folder_id"},
          "type" => "files"
        }
      }
  """
  @spec move_file(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def move_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("files/#{file_id}")
    |> Request.with_method(:patch)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Copies a file to another folder.

  ## Parameters

    - `input` - InputRequest with `body` containing destination parent_id
    - `file_id` - The file ID

  ## Body Format

      %{
        "data" => %{
          "attributes" => %{"parent_id" => "destination_folder_id"},
          "type" => "files"
        }
      }
  """
  @spec copy_file(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def copy_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("files/#{file_id}/copy")
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Deletes a file.

  ## Parameters

    - `input` - InputRequest with access token
    - `file_id` - The file ID to delete
  """
  @spec delete_file(InputRequest.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def delete_file(%InputRequest{} = r, file_id) do
    construct_request(r)
    |> Request.with_path("files/#{file_id}")
    |> Request.with_method(:delete)
    |> Request.send()
  end

  @doc """
  Searches for files.

  ## Parameters

    - `input` - InputRequest with `query_params` containing:
      - `search_string` - The search query

  ## Returns

    - `{:ok, %{"data" => [files]}}` on success
  """
  @spec search_files(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def search_files(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("files/search")
    |> Request.with_method(:get)
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new("workdrive")
    |> Request.with_version("v1")
    |> Request.set_access_token(ir.access_token)
    |> Request.with_params(ir.query_params)
  end

  defp mime_type(file_path) do
    ext = file_path |> Path.extname() |> String.downcase()
    Map.get(@mime_types, ext, "application/octet-stream")
  end
end
