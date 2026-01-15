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
      - `:service` - `:crm` (default) or `:recruit`

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
  def create_job(%InputRequest{} = r, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)

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
      - `:service` - `:crm` (default) or `:recruit`

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
  def get_job_status(%InputRequest{} = r, job_id, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)

    with :ok <- Validation.validate_id(job_id) do
      construct_request(r, service)
      |> Request.with_path("read/#{job_id}")
      |> Request.with_method(:get)
      |> Request.send()
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
