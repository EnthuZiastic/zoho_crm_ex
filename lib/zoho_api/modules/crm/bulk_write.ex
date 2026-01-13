defmodule ZohoAPI.Modules.CRM.BulkWrite do
  @moduledoc """
  Zoho CRM Bulk Write API.

  The Bulk Write API enables you to insert, update, or upsert up to 25,000
  records in a single operation. The process involves:

  1. Upload a CSV/ZIP file containing records
  2. Create a bulk write job with the file ID
  3. Poll for job completion
  4. Check results

  ## Limits

    - **Maximum file size:** 25 MB
    - **Maximum records per job:** 25,000
    - Files exceeding 25 MB will be rejected with an error

  ## Supported Operations

    - `insert` - Insert new records
    - `update` - Update existing records
    - `upsert` - Insert or update based on duplicate criteria

  ## Examples

      # Step 1: Upload the CSV file
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(csv_content)

      {:ok, %{"details" => %{"file_id" => file_id}}} = BulkWrite.upload_file(input, "Leads")

      # Step 2: Create the bulk write job
      job_input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "operation" => "insert",
        "resource" => [
          %{
            "type" => "data",
            "module" => %{"api_name" => "Leads"},
            "file_id" => file_id,
            "field_mappings" => [
              %{"api_name" => "Last_Name", "index" => 0},
              %{"api_name" => "Email", "index" => 1}
            ]
          }
        ]
      })

      {:ok, %{"details" => %{"id" => job_id}}} = BulkWrite.create_job(job_input)

      # Step 3: Check job status
      {:ok, status} = BulkWrite.get_job_status(input, job_id)
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request
  alias ZohoAPI.Validation

  @doc """
  Uploads a CSV or ZIP file for bulk write operations.

  The file should be a CSV with headers matching the field mappings
  you'll use in the job creation.

  ## Parameters

    - `input` - InputRequest with `body` containing the file content
    - `module_name` - The target module API name (e.g., "Leads")

  ## Returns

    - `{:ok, %{"status" => "success", "details" => %{"file_id" => "..."}}}` on success
    - `{:error, reason}` on failure
  """
  # Maximum file size for bulk write uploads (25MB)
  @max_file_size 25 * 1024 * 1024

  @spec upload_file(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def upload_file(%InputRequest{} = r, module_name) do
    with :ok <- validate_file_size(r.body) do
      Request.new("bulk")
      |> Request.set_access_token(r.access_token)
      |> Request.with_path("write/file")
      |> Request.with_params(%{"module" => module_name})
      |> Request.set_headers(%{"Content-Type" => "text/csv"})
      |> Request.with_body(r.body)
      |> Request.with_method(:post)
      |> Request.send()
    end
  end

  defp validate_file_size(body) when is_binary(body) do
    size = byte_size(body)

    if size > @max_file_size do
      {:error,
       %{
         code: "FILE_SIZE_EXCEEDED",
         message:
           "File size #{format_size(size)} exceeds maximum allowed size of #{format_size(@max_file_size)}",
         details: %{
           actual_size: size,
           max_size: @max_file_size
         }
       }}
    else
      :ok
    end
  end

  defp validate_file_size(_) do
    {:error,
     %{
       code: "INVALID_FILE_BODY",
       message: "File body must be binary data"
     }}
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  @doc """
  Creates a bulk write job.

  ## Parameters

    - `input` - InputRequest with `body` containing:
      - `operation` - "insert", "update", or "upsert"
      - `resource` - Array of resource configurations

  ## Body Format

      %{
        "operation" => "insert",
        "resource" => [
          %{
            "type" => "data",
            "module" => %{"api_name" => "Leads"},
            "file_id" => "file_id_from_upload",
            "field_mappings" => [
              %{"api_name" => "Last_Name", "index" => 0}
            ]
          }
        ]
      }

  ## Returns

    - `{:ok, %{"status" => "ADDED", "details" => %{"id" => "job_id"}}}` on success
  """
  @spec create_job(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def create_job(%InputRequest{} = r) do
    Request.new("bulk")
    |> Request.set_access_token(r.access_token)
    |> Request.with_path("write")
    |> Request.with_body(r.body)
    |> Request.with_method(:post)
    |> Request.send()
  end

  @doc """
  Gets the status of a bulk write job.

  ## Parameters

    - `input` - InputRequest with access token
    - `job_id` - The bulk write job ID

  ## Returns

    - `{:ok, %{"status" => "COMPLETED" | "IN_PROGRESS" | "QUEUED" | ...}}`
  """
  @spec get_job_status(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_job_status(%InputRequest{} = r, job_id) do
    with :ok <- Validation.validate_id(job_id) do
      Request.new("bulk")
      |> Request.set_access_token(r.access_token)
      |> Request.with_path("write/#{job_id}")
      |> Request.with_method(:get)
      |> Request.send()
    end
  end
end
