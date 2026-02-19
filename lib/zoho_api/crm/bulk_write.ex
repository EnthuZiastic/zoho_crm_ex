defmodule ZohoAPI.CRM.BulkWrite do
  @moduledoc """
  High-level Zoho CRM Bulk Write client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Accepts
  plain record lists and handles CSV conversion, file upload, job creation,
  and polling internally.

  ## Limits

  - Maximum 25,000 records per job
  - Maximum 25 MB file size

  ## Examples

      records = [%{"Batch_ID" => "123", "Name" => "Test Batch"}]
      {:ok, job_id} = ZohoAPI.CRM.BulkWrite.create_job("Batches", records,
        duplicate_check_fields: ["Batch_ID"])
      {:ok, status} = ZohoAPI.CRM.BulkWrite.poll_until_complete(job_id)
  """

  require Logger

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.BulkWrite, as: BulkWriteAPI
  alias ZohoAPI.TokenCache

  @max_records_per_job 25_000

  @spec create_job(String.t(), list(map()), keyword()) ::
          {:ok, String.t()} | {:error, any()}
  def create_job(module_name, records, opts \\ []) when is_list(records) do
    cond do
      Enum.empty?(records) ->
        {:error, "Cannot create bulk write job with empty records list"}

      length(records) > @max_records_per_job ->
        {:error, "Cannot process more than #{@max_records_per_job} records in a single job"}

      true ->
        do_create_job(module_name, records, opts)
    end
  end

  @spec get_job_status(String.t()) :: {:ok, map()} | {:error, any()}
  def get_job_status(job_id) when is_binary(job_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(nil)
      |> BulkWriteAPI.get_job_status(job_id)
    end
  end

  @spec poll_until_complete(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def poll_until_complete(job_id, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 60)
    poll_interval = Keyword.get(opts, :poll_interval, 5_000)
    poll_job(job_id, max_attempts, poll_interval, 0)
  end

  defp do_create_job(module_name, records, opts) do
    operation = Keyword.get(opts, :operation, "upsert")
    duplicate_check_fields = Keyword.get(opts, :duplicate_check_fields, [])
    csv_data = records_to_csv(records)

    with {:ok, token} <- TokenCache.get_or_refresh(:crm),
         input <- InputRequest.new(token, nil, %{}, csv_data),
         {:ok, upload_response} <- BulkWriteAPI.upload_file(input, module_name),
         file_id <- get_in(upload_response, ["details", "file_id"]) do
      job_body = %{
        "operation" => operation,
        "resource" => [
          %{
            "type" => "data",
            "module" => %{
              "api_name" => module_name,
              "field_mappings" => build_field_mappings(records)
            },
            "file_id" => file_id,
            "find_by" => duplicate_check_fields
          }
        ]
      }

      job_input = InputRequest.new(token, nil, %{}, job_body)

      case BulkWriteAPI.create_job(job_input) do
        {:ok, %{"details" => %{"id" => job_id}}} -> {:ok, job_id}
        {:ok, response} -> {:error, response}
        {:error, _} = error -> error
      end
    end
  end

  defp poll_job(_job_id, max_attempts, _interval, attempt) when attempt >= max_attempts,
    do: {:error, :timeout}

  defp poll_job(job_id, max_attempts, interval, attempt) do
    case get_job_status(job_id) do
      {:ok, %{"state" => "COMPLETED"} = status} ->
        {:ok, status}

      {:ok, %{"state" => "FAILED"} = status} ->
        {:error, status}

      {:ok, %{"state" => state}} when state in ["ADDED", "IN PROGRESS"] ->
        Logger.debug("Bulk write job #{job_id} status: #{state}, attempt #{attempt + 1}")
        Process.sleep(interval)
        poll_job(job_id, max_attempts, interval, attempt + 1)

      {:error, _} = error ->
        error

      other ->
        {:error, other}
    end
  end

  defp build_field_mappings([_first | _] = records) do
    all_keys =
      records
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    Enum.map(all_keys, fn key ->
      %{"api_name" => key, "index" => Enum.find_index(all_keys, &(&1 == key))}
    end)
  end

  defp build_field_mappings(_), do: []

  defp records_to_csv([_first | _] = records) do
    all_keys =
      records
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    header = Enum.join(all_keys, ",")

    rows =
      Enum.map(records, fn record ->
        Enum.map_join(all_keys, ",", fn key ->
          record |> Map.get(key, "") |> csv_escape()
        end)
      end)

    Enum.join([header | rows], "\n")
  end

  defp records_to_csv(_), do: ""

  defp csv_escape(nil), do: ""

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r", "\t"]) do
      ~s("#{String.replace(value, "\"", "\"\"")}")
    else
      value
    end
  end

  defp csv_escape(value), do: to_string(value)
end
