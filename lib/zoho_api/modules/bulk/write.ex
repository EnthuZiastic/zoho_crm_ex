defmodule ZohoAPI.Modules.Bulk.Write do
  @moduledoc """
  Generic Bulk Write API for Zoho services.

  Supports bulk write operations for:
  - Zoho CRM (up to 25,000 records)
  - Zoho Recruit (up to 25,000 records)

  The Bulk Write API enables you to insert, update, or upsert large numbers
  of records in a single operation. The process involves:

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

  ### CRM Bulk Write

      # Step 1: Upload the CSV file
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(csv_content)

      {:ok, %{"details" => %{"file_id" => file_id}}} = BulkWrite.upload_file(input, "Leads", service: :crm)

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

      {:ok, %{"details" => %{"id" => job_id}}} = BulkWrite.create_job(job_input, service: :crm)

  ### Recruit Bulk Write

      {:ok, %{"details" => %{"file_id" => file_id}}} = BulkWrite.upload_file(input, "Candidates", service: :recruit)
      {:ok, %{"details" => %{"id" => job_id}}} = BulkWrite.create_job(job_input, service: :recruit)
      {:ok, status} = BulkWrite.get_job_status(input, job_id, service: :recruit)
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request
  alias ZohoAPI.Validation

  # Maximum file size for bulk write uploads (25MB)
  @max_file_size 25 * 1024 * 1024

  @type service :: :crm | :recruit

  @doc """
  Uploads a CSV or ZIP file for bulk write operations.

  The file should be a CSV with headers matching the field mappings
  you'll use in the job creation.

  ## Parameters

    - `input` - InputRequest with `body` containing the file content
    - `module_name` - The target module API name (e.g., "Leads", "Candidates")
    - `opts` - Options:
      - `:service` - `:crm` (default) or `:recruit`

  ## Memory Considerations

  **Important:** The file content must be loaded into memory before calling this
  function. File size validation occurs after the data is in memory.

  For large files approaching the 25 MB limit:
  - Check file size before reading into memory using `File.stat!/1`
  - Consider chunking or batching if processing multiple files
  - The validation will reject files > 25 MB with a descriptive error

  ```elixir
  # Recommended: Check size before loading
  %{size: size} = File.stat!(file_path)
  if size > 25 * 1024 * 1024 do
    {:error, :file_too_large}
  else
    content = File.read!(file_path)
    BulkWrite.upload_file(input |> InputRequest.with_body(content), "Leads", service: :crm)
  end
  ```

  ## Returns

    - `{:ok, %{"status" => "success", "details" => %{"file_id" => "..."}}}` on success
    - `{:error, reason}` on failure
  """
  @spec upload_file(InputRequest.t(), String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def upload_file(%InputRequest{} = r, module_name, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)

    with :ok <- validate_file_size(r.body) do
      construct_request(r, service)
      |> Request.with_path("write/file")
      |> Request.with_params(%{"module" => module_name})
      |> Request.set_headers(%{"Content-Type" => "text/csv"})
      |> Request.with_body(r.body)
      |> Request.with_method(:post)
      |> Request.send()
    end
  end

  @doc """
  Creates a bulk write job.

  ## Parameters

    - `input` - InputRequest with `body` containing:
      - `operation` - "insert", "update", or "upsert"
      - `resource` - Array of resource configurations
    - `opts` - Options:
      - `:service` - `:crm` (default) or `:recruit`

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
  @spec create_job(InputRequest.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def create_job(%InputRequest{} = r, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)

    construct_request(r, service)
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
    - `opts` - Options:
      - `:service` - `:crm` (default) or `:recruit`

  ## Returns

    - `{:ok, %{"status" => "COMPLETED" | "IN_PROGRESS" | "QUEUED" | ...}}`
  """
  @spec get_job_status(InputRequest.t(), String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def get_job_status(%InputRequest{} = r, job_id, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)

    with :ok <- Validation.validate_id(job_id) do
      construct_request(r, service)
      |> Request.with_path("write/#{job_id}")
      |> Request.with_method(:get)
      |> Request.send()
    end
  end

  defp construct_request(%InputRequest{} = ir, service) do
    api_type = api_type_for_service(service)

    Request.new(api_type)
    |> Request.set_access_token(ir.access_token)
    |> Request.with_region(ir.region)
  end

  defp api_type_for_service(:crm), do: "bulk"
  defp api_type_for_service(:recruit), do: "recruit_bulk"

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
end
