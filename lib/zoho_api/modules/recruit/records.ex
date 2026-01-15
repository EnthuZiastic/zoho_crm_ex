defmodule ZohoAPI.Modules.Recruit.Records do
  @moduledoc """
  Zoho Recruit Records API (v2).

  This module handles all record-level operations for Zoho Recruit modules
  such as Candidates, Job_Openings, Clients, Contacts, etc.

  ## Features

    - CRUD operations (Create, Read, Update, Delete)
    - Upsert with duplicate check
    - Search using criteria
    - Get specific record by ID
    - Get associated records
    - **Streaming pagination** - Efficiently process large datasets
    - **Auto token refresh** - Automatic 401 handling with retry

  ## Basic Examples

      # Get all records from Candidates module
      input = InputRequest.new("access_token")
      |> InputRequest.with_module_api_name("Candidates")

      {:ok, records} = Records.get_records(input)

      # Insert new records
      input = InputRequest.new("access_token")
      |> InputRequest.with_module_api_name("Candidates")
      |> InputRequest.with_body([%{"Last_Name" => "Smith", "Email" => "smith@example.com"}])

      {:ok, result} = Records.insert_records(input)

  ## Advanced Examples (with Client features)

      # With automatic token refresh and retry
      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("refresh_token")
      |> InputRequest.with_module_api_name("Candidates")

      {:ok, records} = Records.get_records_with_client(input)

      # Stream all records (lazy, memory efficient)
      Records.stream_all(input)
      |> Stream.filter(&(&1["Status"] == "Active"))
      |> Enum.take(1000)

      # Fetch all records at once
      {:ok, all_candidates} = Records.fetch_all_records(input)
  """

  alias ZohoAPI.Client
  alias ZohoAPI.InputRequest
  alias ZohoAPI.Pagination
  alias ZohoAPI.Request
  alias ZohoAPI.Validation

  @doc """
  Gets records from a Zoho Recruit module.

  ## Parameters

    - `input` - InputRequest with `module_api_name` set

  ## Returns

    - `{:ok, %{"data" => [...]}}` on success
    - `{:error, reason}` on failure
  """
  @spec get_records(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def get_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path(r.module_api_name)
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Gets a specific record by ID.

  ## Parameters

    - `input` - InputRequest with `module_api_name` set
    - `record_id` - The record ID

  ## Returns

    - `{:ok, %{"data" => [record]}}` on success
    - `{:error, reason}` on failure
  """
  @spec get_record(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_record(%InputRequest{} = r, record_id) do
    with :ok <- Validation.validate_id(record_id) do
      construct_request(r)
      |> Request.with_path("#{r.module_api_name}/#{record_id}")
      |> Request.with_method(:get)
      |> Request.send()
    end
  end

  @doc """
  Inserts new records into a Zoho Recruit module.

  ## Parameters

    - `input` - InputRequest with `module_api_name` and `body` (list of records)

  ## Returns

    - `{:ok, result}` on success
    - `{:error, reason}` on failure
  """
  @spec insert_records(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def insert_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path(r.module_api_name)
    |> Request.send()
  end

  @doc """
  Upserts records (insert or update based on duplicate check).

  ## Parameters

    - `input` - InputRequest with `module_api_name` and `body`
    - `opts` - Options including:
      - `:duplicate_check_fields` - List of fields for duplicate detection

  ## Examples

      input = InputRequest.new("token")
      |> InputRequest.with_module_api_name("Candidates")
      |> InputRequest.with_body([%{"Email" => "test@example.com"}])

      Records.upsert_records(input, duplicate_check_fields: ["Email"])
  """
  @spec upsert_records(InputRequest.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def upsert_records(%InputRequest{} = r, opts \\ []) do
    request = construct_request(r)

    updated_request =
      case Keyword.get(opts, :duplicate_check_fields) do
        fields when is_list(fields) ->
          body = Map.merge(request.body, %{"duplicate_check_fields" => fields})
          Request.with_body(request, body)

        _ ->
          request
      end

    updated_request
    |> Request.with_method(:post)
    |> Request.with_path("#{r.module_api_name}/upsert")
    |> Request.send()
  end

  @doc """
  Updates existing records in a Zoho Recruit module.

  ## Parameters

    - `input` - InputRequest with `module_api_name` and `body` (records with IDs)
  """
  @spec update_records(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def update_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:put)
    |> Request.with_path(r.module_api_name)
    |> Request.send()
  end

  @doc """
  Searches records using criteria.

  ## Parameters

    - `input` - InputRequest with `module_api_name` and `query_params` containing:
      - `criteria` - Search criteria string
  """
  @spec search_records(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def search_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{r.module_api_name}/search")
    |> Request.send()
  end

  @doc """
  Deletes records from a Zoho Recruit module.

  ## Parameters

    - `input` - InputRequest with `module_api_name` and `query_params` containing `ids`
  """
  @spec delete_records(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def delete_records(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:delete)
    |> Request.with_path(r.module_api_name)
    |> Request.send()
  end

  @doc """
  Gets associated records for a specific record.

  ## Parameters

    - `input` - InputRequest with `module_api_name` set
    - `record_id` - The record ID to get associations for

  ## Returns

    - `{:ok, %{"data" => [...]}}` on success
    - `{:error, reason}` on failure
  """
  @spec get_associated_records(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_associated_records(%InputRequest{} = r, record_id) do
    with :ok <- Validation.validate_id(record_id) do
      construct_request(r)
      |> Request.with_path("#{r.module_api_name}/#{record_id}/associate")
      |> Request.with_method(:get)
      |> Request.send()
    end
  end

  # ============================================================================
  # Advanced Functions (with Client features)
  # ============================================================================

  @doc """
  Gets records with full Client features (retry, token refresh, rate limiting).

  This is the recommended way to fetch records when you need:
  - Automatic retry on transient failures
  - Automatic token refresh on 401
  - Rate limiting (if configured)

  ## Parameters

    - `input` - InputRequest with `module_api_name` set

  ## Configuration

  For token auto-refresh, set:
  - `InputRequest.with_refresh_token/2`
  - Optionally `InputRequest.with_on_token_refresh/2` for callback

  For custom retry:
  - `InputRequest.with_retry_opts/2`

  ## Examples

      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("refresh_token")
      |> InputRequest.with_module_api_name("Candidates")

      {:ok, records} = Records.get_records_with_client(input)
  """
  @spec get_records_with_client(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def get_records_with_client(%InputRequest{} = r) do
    request =
      construct_request(r)
      |> Request.with_path(r.module_api_name)
      |> Request.with_method(:get)

    Client.send(request, r)
  end

  @doc """
  Stream all records with automatic pagination.

  Creates a lazy stream that fetches pages on-demand. This is memory efficient
  for large datasets as only one page is in memory at a time.

  Uses Client features (retry, token refresh) for each page fetch.

  ## Parameters

    - `input` - InputRequest with `module_api_name` set
    - `opts` - Pagination options:
      - `:per_page` - Records per page (default: 200)
      - `:max_records` - Maximum records to fetch (default: unlimited)

  ## Examples

      input = InputRequest.new("access_token")
      |> InputRequest.with_refresh_token("refresh_token")
      |> InputRequest.with_module_api_name("Candidates")

      # Process all active candidates
      Records.stream_all(input)
      |> Stream.filter(&(&1["Status"] == "Active"))
      |> Stream.each(&process_candidate/1)
      |> Stream.run()

      # Take first 1000 records
      candidates = Records.stream_all(input) |> Enum.take(1000)

      # Limit total records
      Records.stream_all(input, max_records: 5000)
      |> Enum.to_list()
  """
  @spec stream_all(InputRequest.t(), keyword()) :: Enumerable.t()
  def stream_all(%InputRequest{} = input, opts \\ []) do
    Pagination.stream_all(input, &get_records_with_client/1, opts)
  end

  @doc """
  Fetch all records with automatic pagination.

  Eagerly fetches all pages and combines them into a single list.
  Use `stream_all/2` for memory-efficient processing of large datasets.

  Uses Client features (retry, token refresh) for each page fetch.

  ## Parameters

    - `input` - InputRequest with `module_api_name` set
    - `opts` - Same options as `stream_all/2`

  ## Examples

      input = InputRequest.new("access_token")
      |> InputRequest.with_module_api_name("Candidates")

      {:ok, all_candidates} = Records.fetch_all_records(input)

      # With limit
      {:ok, candidates} = Records.fetch_all_records(input, max_records: 1000)
  """
  @spec fetch_all_records(InputRequest.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def fetch_all_records(%InputRequest{} = input, opts \\ []) do
    Pagination.fetch_all(input, &get_records_with_client/1, opts)
  end

  # ============================================================================
  # Deprecated Functions (for backwards compatibility)
  # ============================================================================

  @doc false
  @deprecated "Use get_records/1 instead"
  def get_recruit_records(%InputRequest{} = r), do: get_records(r)

  @doc false
  @deprecated "Use insert_records/1 instead"
  def insert_recruit_records(%InputRequest{} = r), do: insert_records(r)

  @doc false
  @deprecated "Use update_records/1 instead"
  def update_recruit_records(%InputRequest{} = r), do: update_records(r)

  @doc false
  @deprecated "Use search_records/1 instead"
  def search_recruit_records(%InputRequest{} = r), do: search_records(r)

  defp construct_request(%InputRequest{} = ir) do
    Request.new("recruit")
    |> Request.set_access_token(ir.access_token)
    |> Request.with_region(ir.region)
    |> Request.with_params(ir.query_params)
    |> Request.with_body(%{"data" => ir.body})
  end
end
