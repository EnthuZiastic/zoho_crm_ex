defmodule ZohoAPI.Recruit do
  @moduledoc """
  High-level Zoho Recruit client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  the Recruit module name (e.g. "Candidates", "Job_Openings") along with data.

  ## Examples

      {:ok, result} = ZohoAPI.Recruit.get_records("Candidates", %{page: 1, per_page: 100})
      {:ok, result} = ZohoAPI.Recruit.get_associated_records("Candidates", candidate_id)
      {:ok, result} = ZohoAPI.Recruit.update_records("Candidates", [%{id: "...", data_synced_to_enthu: true}])
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Recruit.Records
  alias ZohoAPI.TokenCache

  @spec get_records(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def get_records(module_name, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name, params)
      |> Records.get_records()
    end
  end

  @spec get_record(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_record(module_name, record_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name)
      |> Records.get_record(record_id)
    end
  end

  @spec search_records(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def search_records(module_name, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name, params)
      |> Records.search_records()
    end
  end

  @spec insert_records(String.t(), list(map())) :: {:ok, map()} | {:error, any()}
  def insert_records(module_name, records) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name, %{}, records)
      |> Records.insert_records()
    end
  end

  @spec update_records(String.t(), list(map())) :: {:ok, map()} | {:error, any()}
  def update_records(module_name, records) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name, %{}, records)
      |> Records.update_records()
    end
  end

  @spec get_associated_records(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_associated_records(module_name, record_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:recruit) do
      token
      |> InputRequest.new(module_name)
      |> Records.get_associated_records(record_id)
    end
  end
end
