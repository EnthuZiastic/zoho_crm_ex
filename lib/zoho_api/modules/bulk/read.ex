defmodule ZohoAPI.Modules.Bulk.Read do
  @moduledoc """
  Generic Bulk Read API for Zoho services.

  Supports bulk read operations for:
  - Zoho CRM (up to 200,000 records)
  - Zoho Recruit (up to 200,000 records)

  The Bulk Read API enables you to export large datasets from
  a module. The process involves:

  1. Create a bulk read job with query criteria
  2. Poll for job completion
  3. Download the result file

  ## Examples

  ### CRM Bulk Read

      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "query" => %{
          "module" => %{"api_name" => "Leads"},
          "fields" => [
            %{"api_name" => "Last_Name"},
            %{"api_name" => "Email"}
          ]
        }
      })

      {:ok, %{"details" => %{"id" => job_id}}} = BulkRead.create_job(input, service: :crm)

  ### Recruit Bulk Read

      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "query" => %{
          "module" => %{"api_name" => "Candidates"},
          "fields" => [
            %{"api_name" => "Last_Name"},
            %{"api_name" => "Email"}
          ]
        }
      })

      {:ok, %{"details" => %{"id" => job_id}}} = BulkRead.create_job(input, service: :recruit)

      # Check job status
      {:ok, status} = BulkRead.get_job_status(input, job_id, service: :recruit)

  ## Timeout Considerations

  Bulk operations process large datasets and may take longer than standard API calls.
  Consider using longer HTTP timeouts when working with bulk operations:

      # Default HTTPoison timeout is 5 seconds which may be insufficient
      # Configure longer timeouts at the application level or use recv_timeout option
      config :zoho_api, :http_options, recv_timeout: 120_000  # 2 minutes

  Polling for job completion is recommended rather than waiting for a single long request.
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request
  alias ZohoAPI.Validation

  @type service :: :crm | :recruit

  @doc """
  Creates a bulk read job.

  ## Parameters

    - `input` - InputRequest with `body` containing query configuration
    - `opts` - Options:
      - `:service` - **Required.** `:crm` or `:recruit`

  ## Body Format

      %{
        "query" => %{
          "module" => %{"api_name" => "Leads"},
          "fields" => [
            %{"api_name" => "Last_Name"},
            %{"api_name" => "Email"}
          ],
          "criteria" => %{         # Optional
            "group_operator" => "and",
            "group" => [
              %{
                "field" => %{"api_name" => "Created_Time"},
                "comparator" => "greater_than",
                "value" => "2024-01-01T00:00:00+00:00"
              }
            ]
          },
          "page" => 1              # Optional, for pagination
        }
      }

  ## Returns

    - `{:ok, %{"status" => "ADDED", "details" => %{"id" => "job_id"}}}` on success
    - `{:error, reason}` on failure
  """
  @spec create_job(InputRequest.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def create_job(%InputRequest{} = r, opts) do
    service = Keyword.fetch!(opts, :service)

    construct_request(r, service)
    |> Request.with_path("read")
    |> Request.with_body(r.body)
    |> Request.with_method(:post)
    |> Request.send()
  end

  @doc """
  Gets the status of a bulk read job.

  ## Parameters

    - `input` - InputRequest with access token
    - `job_id` - The bulk read job ID
    - `opts` - Options:
      - `:service` - **Required.** `:crm` or `:recruit`

  ## Returns

    Status can be:
    - `QUEUED` - Job is in queue
    - `IN_PROGRESS` - Job is running
    - `COMPLETED` - Job finished, download URL available
    - `FAILED` - Job failed

    When completed:
      %{
        "status" => "COMPLETED",
        "result" => %{
          "download_url" => "https://...",
          "count" => 1500,
          "more_records" => false
        }
      }
  """
  @spec get_job_status(InputRequest.t(), String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def get_job_status(%InputRequest{} = r, job_id, opts) do
    service = Keyword.fetch!(opts, :service)

    with :ok <- Validation.validate_id(job_id) do
      construct_request(r, service)
      |> Request.with_path("read/#{job_id}")
      |> Request.with_method(:get)
      |> Request.send()
    end
  end

  @doc """
  Polls for job completion until the job reaches a terminal state.

  This convenience function repeatedly checks the job status until
  it reaches `COMPLETED` or `FAILED`, saving you from implementing
  your own polling logic.

  ## Parameters

    - `input` - InputRequest with access token
    - `job_id` - The bulk read job ID
    - `opts` - Options:
      - `:service` - **Required.** `:crm` or `:recruit`
      - `:interval` - Poll interval in milliseconds (default: 5000)
      - `:max_attempts` - Maximum poll attempts (default: 60, ~5 minutes with default interval)

  ## Returns

    - `{:ok, result}` - When job completes successfully, returns the final status with download_url
    - `{:error, :job_failed}` - When job fails
    - `{:error, :timeout}` - When max_attempts is exceeded
    - `{:error, reason}` - When API call fails

  ## Examples

      input = InputRequest.new("access_token")
      {:ok, result} = BulkRead.wait_for_completion(input, job_id, service: :crm)
      download_url = result["result"]["download_url"]
  """
  @spec wait_for_completion(InputRequest.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, any()}
  def wait_for_completion(%InputRequest{} = input, job_id, opts) do
    _service = Keyword.fetch!(opts, :service)
    interval = Keyword.get(opts, :interval, 5_000)
    max_attempts = Keyword.get(opts, :max_attempts, 60)

    do_poll(input, job_id, opts, interval, max_attempts, 0)
  end

  defp do_poll(_input, _job_id, _opts, _interval, max_attempts, attempt)
       when attempt >= max_attempts do
    {:error, :timeout}
  end

  defp do_poll(input, job_id, opts, interval, max_attempts, attempt) do
    case get_job_status(input, job_id, opts) do
      {:ok, %{"status" => "COMPLETED"} = result} ->
        {:ok, result}

      {:ok, %{"status" => "FAILED"}} ->
        {:error, :job_failed}

      {:ok, %{"status" => status}} when status in ["QUEUED", "IN_PROGRESS"] ->
        Process.sleep(interval)
        do_poll(input, job_id, opts, interval, max_attempts, attempt + 1)

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Downloads the result file from a completed bulk read job.

  After a job completes, use this function to download the CSV data
  from the provided download URL.

  ## Parameters

    - `download_url` - The URL from the completed job's `result.download_url`
    - `opts` - Options:
      - `:timeout` - HTTP timeout in milliseconds (default: 120_000)

  ## Returns

    - `{:ok, binary}` - The raw CSV content as binary
    - `{:error, reason}` - On failure

  ## Examples

      {:ok, result} = BulkRead.wait_for_completion(input, job_id, service: :crm)
      {:ok, csv_data} = BulkRead.download_result(result["result"]["download_url"])

      # Parse CSV data
      csv_data
      |> String.split("\\n")
      |> Enum.map(&String.split(&1, ","))
  """
  @spec download_result(String.t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def download_result(download_url, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 120_000)

    case HTTPoison.get(download_url, [], recv_timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, %{status_code: status_code, body: body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp construct_request(%InputRequest{} = ir, service) do
    {api_type, version} = api_config_for_service(service)

    Request.new(api_type)
    |> Request.with_version(version)
    |> Request.set_access_token(ir.access_token)
    |> Request.with_region(ir.region)
  end

  # CRM Bulk uses v8, Recruit Bulk uses v2
  defp api_config_for_service(:crm), do: {"bulk", "v8"}
  defp api_config_for_service(:recruit), do: {"recruit_bulk", "v2"}
end
