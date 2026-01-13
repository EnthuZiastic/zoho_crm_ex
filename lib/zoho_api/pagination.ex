defmodule ZohoAPI.Pagination do
  @moduledoc """
  Pagination helpers for Zoho APIs.

  This module provides streaming and batch fetching utilities for paginated
  Zoho API responses. It handles the complexity of pagination so you can
  work with large datasets efficiently.

  ## Zoho Pagination Format

  Zoho CRM and similar APIs return paginated responses in this format:

      %{
        "data" => [...],
        "info" => %{
          "per_page" => 200,
          "count" => 200,
          "page" => 1,
          "more_records" => true
        }
      }

  ## Streaming vs Fetching

  **Streaming** (`stream_all/3`) - Lazy evaluation, memory efficient:
  - Records are fetched page by page as you consume the stream
  - Only one page is in memory at a time
  - Best for processing large datasets or when you may not need all records

  **Fetching** (`fetch_all/3`) - Eager evaluation, simpler:
  - All pages are fetched and combined into a single list
  - Entire dataset is loaded into memory
  - Best for smaller datasets or when you need all records at once

  ## Examples

      input = InputRequest.new("token")
      |> InputRequest.with_module_api_name("Leads")

      # Stream lazily - memory efficient
      Records.stream_all(input)
      |> Stream.filter(&(&1["Status"] == "Active"))
      |> Stream.take(1000)
      |> Enum.to_list()

      # Fetch all at once
      {:ok, all_leads} = Pagination.fetch_all(input, &Records.get_records/1)

      # With options
      Records.stream_all(input, per_page: 100, max_records: 5000)
      |> Enum.each(&process_record/1)
  """

  alias ZohoAPI.InputRequest

  @default_per_page 200
  @default_max_records :infinity

  @type fetch_fn :: (InputRequest.t() -> {:ok, map()} | {:error, any()})

  @doc """
  Create a Stream that lazily fetches all pages.

  The stream fetches pages on-demand as you consume it, making it memory
  efficient for large datasets.

  ## Parameters

    - `input` - The InputRequest with access token and configuration
    - `fetch_fn` - A function that takes InputRequest and returns `{:ok, response}`
    - `opts` - Options (see below)

  ## Options

    - `:per_page` - Records per page (default: 200, max varies by API)
    - `:max_records` - Maximum total records to fetch (default: unlimited)
    - `:page_param` - Query param name for page (default: "page")
    - `:per_page_param` - Query param name for per_page (default: "per_page")

  ## Returns

    An `Enumerable.t()` that yields individual records.

  ## Examples

      input = InputRequest.new("token")
      |> InputRequest.with_module_api_name("Leads")

      # Take first 100 active leads
      Records.stream_all(input)
      |> Stream.filter(&(&1["Status"] == "Active"))
      |> Enum.take(100)

      # Process all leads with limited memory usage
      Records.stream_all(input)
      |> Stream.each(&process_lead/1)
      |> Stream.run()

      # Limit to 5000 records
      Records.stream_all(input, max_records: 5000)
      |> Enum.to_list()

  ## Error Handling

  If a page fetch fails, the stream emits a `{:error, reason}` tuple and halts.
  You can handle errors by filtering or using `Enum.reduce_while/3`:

      input
      |> Records.stream_all()
      |> Enum.reduce_while([], fn
        {:error, reason} -> {:halt, {:error, reason}}
        record -> {:cont, [record | acc]}
      end)
  """
  @spec stream_all(InputRequest.t(), fetch_fn(), keyword()) :: Enumerable.t()
  def stream_all(%InputRequest{} = input, fetch_fn, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, @default_per_page)
    max_records = Keyword.get(opts, :max_records, @default_max_records)
    page_param = Keyword.get(opts, :page_param, "page")
    per_page_param = Keyword.get(opts, :per_page_param, "per_page")

    Stream.resource(
      fn ->
        %{
          page: 1,
          per_page: per_page,
          max_records: max_records,
          fetched_count: 0,
          done: false,
          page_param: page_param,
          per_page_param: per_page_param
        }
      end,
      fn state ->
        if state.done or reached_limit?(state) do
          {:halt, state}
        else
          fetch_page(input, fetch_fn, state)
        end
      end,
      fn _state -> :ok end
    )
  end

  @doc """
  Fetch all pages and return combined data.

  This eagerly fetches all pages and combines them into a single list.
  Use this when you need all records and memory is not a concern.

  ## Parameters

    - `input` - The InputRequest with access token and configuration
    - `fetch_fn` - A function that takes InputRequest and returns `{:ok, response}`
    - `opts` - Same options as `stream_all/3`

  ## Returns

    - `{:ok, [record, ...]}` - All records combined
    - `{:error, reason}` - If any page fetch fails

  ## Examples

      {:ok, all_leads} = Pagination.fetch_all(input, &Records.get_records/1)

      {:ok, recent_leads} = Pagination.fetch_all(
        input,
        &Records.get_records/1,
        max_records: 1000
      )
  """
  @spec fetch_all(InputRequest.t(), fetch_fn(), keyword()) ::
          {:ok, [map()]} | {:error, any()}
  def fetch_all(%InputRequest{} = input, fetch_fn, opts \\ []) do
    stream_all(input, fetch_fn, opts)
    |> Enum.reduce_while({:ok, []}, fn
      {:error, reason}, _acc ->
        {:halt, {:error, reason}}

      record, {:ok, records} ->
        {:cont, {:ok, [record | records]}}
    end)
    |> case do
      {:ok, records} -> {:ok, Enum.reverse(records)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Fetch a single page with pagination parameters.

  Lower-level function for custom pagination handling.

  ## Parameters

    - `input` - The InputRequest
    - `fetch_fn` - The fetch function
    - `page` - Page number (1-indexed)
    - `per_page` - Records per page

  ## Returns

    - `{:ok, records, more_records}` - Records and whether more pages exist
    - `{:error, reason}` - On failure
  """
  @spec fetch_page(InputRequest.t(), fetch_fn(), pos_integer(), pos_integer()) ::
          {:ok, [map()], boolean()} | {:error, any()}
  def fetch_page(%InputRequest{} = input, fetch_fn, page, per_page) do
    pagination_params = %{
      "page" => page,
      "per_page" => per_page
    }

    current_params = input.query_params || %{}
    updated_input = %{input | query_params: Map.merge(current_params, pagination_params)}

    case fetch_fn.(updated_input) do
      {:ok, %{"data" => data, "info" => info}} ->
        more_records = Map.get(info, "more_records", false)
        {:ok, data, more_records}

      {:ok, %{"data" => data}} ->
        {:ok, data, false}

      {:ok, data} when is_list(data) ->
        {:ok, data, false}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp reached_limit?(%{max_records: :infinity}), do: false
  defp reached_limit?(%{fetched_count: fetched, max_records: max}), do: fetched >= max

  defp fetch_page(input, fetch_fn, state) do
    pagination_params = %{
      state.page_param => state.page,
      state.per_page_param => state.per_page
    }

    current_params = input.query_params || %{}
    updated_input = %{input | query_params: Map.merge(current_params, pagination_params)}

    case fetch_fn.(updated_input) do
      {:ok, %{"data" => data, "info" => info}} ->
        more_records = Map.get(info, "more_records", false)
        process_page_result(data, more_records, state)

      {:ok, %{"data" => data}} ->
        # No info block - assume single page
        process_page_result(data, false, state)

      {:ok, data} when is_list(data) ->
        # Direct list response
        process_page_result(data, false, state)

      {:ok, _other} ->
        # Unexpected format, treat as empty
        {[], %{state | done: true}}

      {:error, reason} ->
        # Emit error tuple and halt the stream
        error = {:error, %{page: state.page, reason: reason}}
        {[error], %{state | done: true}}
    end
  end

  defp process_page_result(data, more_records, state) do
    {records_to_return, new_fetched_count} =
      limit_records(data, state.fetched_count, state.max_records)

    done =
      not more_records or
        records_to_return == [] or
        reached_limit?(%{state | fetched_count: new_fetched_count})

    new_state = %{
      state
      | page: state.page + 1,
        fetched_count: new_fetched_count,
        done: done
    }

    {records_to_return, new_state}
  end

  defp limit_records(data, fetched_count, :infinity) do
    {data, fetched_count + length(data)}
  end

  defp limit_records(data, fetched_count, max_records) do
    remaining = max_records - fetched_count
    limited = Enum.take(data, remaining)
    {limited, fetched_count + length(limited)}
  end
end
