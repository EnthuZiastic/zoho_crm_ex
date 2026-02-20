defmodule ZohoAPI.Modules.Records do
  @moduledoc """
  Legacy wrapper for Zoho CRM Records API.

  **DEPRECATED**: This module is maintained for backward compatibility only.
  New code should use `ZohoAPI.Modules.CRM.Records` directly.

  ## Migration

  Replace:
      alias ZohoAPI.Modules.Records

  With:
      alias ZohoAPI.Modules.CRM.Records
  """

  alias ZohoAPI.Modules.CRM.Records, as: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.get_records/1 instead"
  defdelegate get_records(input), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.get_record/2 instead"
  defdelegate get_record(input, record_id), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.insert_records/1 instead"
  defdelegate insert_records(input), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.upsert_records/2 instead"
  defdelegate upsert_records(input, opts \\ []), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.update_records/1 instead"
  defdelegate update_records(input), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.search_records/1 instead"
  defdelegate search_records(input), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.delete_records/1 instead"
  defdelegate delete_records(input), to: CRMRecords

  @deprecated "Use ZohoAPI.Modules.CRM.Records.coql_query/1 instead"
  defdelegate coql_query(input), to: CRMRecords
end
