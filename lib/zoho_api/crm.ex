defmodule ZohoAPI.CRM do
  @moduledoc """
  Generic high-level Zoho CRM client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  the CRM module name (e.g. "Leads", "Contacts", "Batches") along with data.

  For frequently-used entities, prefer the entity-specific modules which omit
  the module name argument entirely:
    - `ZohoAPI.CRM.Leads`
    - `ZohoAPI.CRM.Contacts`

  For any entity without a dedicated module, use the functions here directly.

  ## Examples

      {:ok, result} = ZohoAPI.CRM.upsert_records("Batches", records, duplicate_check_fields: ["Batch_ID"])
      {:ok, result} = ZohoAPI.CRM.search_records("Leads", %{criteria: "(Email:equals:foo@example.com)"})
      {:ok, result} = ZohoAPI.CRM.coql_query("select Email from Leads where Email is not null")
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.Composite
  alias ZohoAPI.Modules.CRM.Records
  alias ZohoAPI.TokenCache

  @spec get_records(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def get_records(module_name, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, params)
      |> Records.get_records()
    end
  end

  @spec get_record(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_record(module_name, record_id) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name)
      |> Records.get_record(record_id)
    end
  end

  @spec search_records(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def search_records(module_name, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, params)
      |> Records.search_records()
    end
  end

  @spec insert_records(String.t(), list(map())) :: {:ok, map()} | {:error, any()}
  def insert_records(module_name, records) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, %{}, records)
      |> Records.insert_records()
    end
  end

  @spec update_records(String.t(), list(map())) :: {:ok, map()} | {:error, any()}
  def update_records(module_name, records) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, %{}, records)
      |> Records.update_records()
    end
  end

  @spec upsert_records(String.t(), list(map()), keyword()) :: {:ok, map()} | {:error, any()}
  def upsert_records(module_name, records, opts \\ []) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, %{}, records)
      |> Records.upsert_records(opts)
    end
  end

  @spec delete_records(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def delete_records(module_name, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(module_name, params)
      |> Records.delete_records()
    end
  end

  @spec coql_query(String.t()) :: {:ok, map()} | {:error, any()}
  def coql_query(query) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(nil, %{}, %{"select_query" => query})
      |> Records.coql_query()
    end
  end

  @spec composite_request(map()) :: {:ok, map()} | {:error, any()}
  def composite_request(body) do
    with {:ok, token} <- TokenCache.get_or_refresh(:crm) do
      token
      |> InputRequest.new(nil, %{}, body)
      |> Composite.execute()
    end
  end
end
