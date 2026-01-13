defmodule ZohoAPI.Modules.Records do
  @moduledoc """
  Legacy wrapper for Zoho CRM Records API.

  This module is maintained for backward compatibility.
  New code should use `ZohoAPI.Modules.CRM.Records` directly.

  ## Migration

  Replace:
      alias ZohoAPI.Modules.Records

  With:
      alias ZohoAPI.Modules.CRM.Records
  """

  alias ZohoAPI.Modules.CRM.Records, as: CRMRecords

  defdelegate get_records(input), to: CRMRecords
  defdelegate get_record(input, record_id), to: CRMRecords
  defdelegate insert_records(input), to: CRMRecords
  defdelegate upsert_records(input, opts \\ []), to: CRMRecords
  defdelegate update_records(input), to: CRMRecords
  defdelegate search_records(input), to: CRMRecords
  defdelegate delete_records(input), to: CRMRecords
  defdelegate coql_query(input), to: CRMRecords
end
