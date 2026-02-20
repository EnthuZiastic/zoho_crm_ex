defmodule ZohoAPI.CRM.Contacts do
  @moduledoc """
  Entity-specific Zoho CRM client for the Contacts module.

  Wraps `ZohoAPI.CRM` with a fixed module name so callers don't need to
  pass "Contacts" explicitly. Fall back to `ZohoAPI.CRM` for any operations
  not listed here.
  """

  alias ZohoAPI.CRM

  @module_name "Contacts"

  @spec get(map()) :: {:ok, map()} | {:error, any()}
  def get(params \\ %{}), do: CRM.get_records(@module_name, params)

  @spec get_by_id(String.t()) :: {:ok, map()} | {:error, any()}
  def get_by_id(id), do: CRM.get_record(@module_name, id)

  @spec search(map()) :: {:ok, map()} | {:error, any()}
  def search(params \\ %{}), do: CRM.search_records(@module_name, params)

  @spec insert(list(map())) :: {:ok, map()} | {:error, any()}
  def insert(records), do: CRM.insert_records(@module_name, records)

  @spec update(list(map())) :: {:ok, map()} | {:error, any()}
  def update(records), do: CRM.update_records(@module_name, records)

  @spec upsert(list(map()), keyword()) :: {:ok, map()} | {:error, any()}
  def upsert(records, opts \\ []), do: CRM.upsert_records(@module_name, records, opts)

  @spec delete(map()) :: {:ok, map()} | {:error, any()}
  def delete(params \\ %{}), do: CRM.delete_records(@module_name, params)
end
