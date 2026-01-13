defmodule ZohoCrm.Modules.CRM.BulkRead do
  @moduledoc """
  Zoho CRM Bulk Read API.

  The Bulk Read API enables you to export up to 200,000 records from
  a CRM module. The process involves:

  1. Create a bulk read job with query criteria
  2. Poll for job completion
  3. Download the result file

  ## Features

    - Export up to 200,000 records per job
    - Filter records using criteria
    - Select specific fields to export
    - Results provided as downloadable CSV/ZIP

  ## Examples

      # Create a bulk read job
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

      {:ok, %{"details" => %{"id" => job_id}}} = BulkRead.create_job(input)

      # Check job status
      {:ok, status} = BulkRead.get_job_status(input, job_id)

      # When status is COMPLETED, download the result
      download_url = status["result"]["download_url"]
  """

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Request

  @doc """
  Creates a bulk read job.

  ## Parameters

    - `input` - InputRequest with `body` containing query configuration

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
  @spec create_job(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def create_job(%InputRequest{} = r) do
    Request.new("bulk")
    |> Request.set_access_token(r.access_token)
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
  @spec get_job_status(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_job_status(%InputRequest{} = r, job_id) do
    Request.new("bulk")
    |> Request.set_access_token(r.access_token)
    |> Request.with_path("read/#{job_id}")
    |> Request.with_method(:get)
    |> Request.send()
  end
end
