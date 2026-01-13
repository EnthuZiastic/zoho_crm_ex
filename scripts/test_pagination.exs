#!/usr/bin/env elixir
# Test script for ZohoAPI Pagination
#
# Usage:
#   mix run scripts/test_pagination.exs
#
# Tests the streaming and fetch_all pagination helpers.
#
# Configuration:
#   Copy scripts/config.example.exs to scripts/config.exs and fill in your values

Mix.install([])

# Load configuration
config_path = Path.join(__DIR__, "config.exs")

unless File.exists?(config_path) do
  IO.puts("""
  Configuration file not found!

  Please copy the example config and fill in your values:
    cp scripts/config.example.exs scripts/config.exs
  """)

  System.halt(1)
end

config = Code.eval_file(config_path) |> elem(0)

alias ZohoAPI.InputRequest
alias ZohoAPI.Modules.CRM.Records
alias ZohoAPI.Modules.Token
alias ZohoAPI.Pagination

IO.puts("=== ZohoAPI Pagination Test Script ===\n")

# Helper to print results
defmodule TestHelper do
  def print_result(name, result) do
    case result do
      {:ok, data} when is_list(data) ->
        IO.puts("[PASS] #{name}")
        IO.puts("  Records: #{length(data)}")

        if length(data) > 0 do
          IO.puts("  First: #{inspect(hd(data), limit: 3)}\n")
        else
          IO.puts("")
        end

        {:ok, data}

      {:ok, data} ->
        IO.puts("[PASS] #{name}")
        IO.puts("  Response: #{inspect(data, limit: 3, pretty: true)}\n")
        {:ok, data}

      {:error, reason} ->
        IO.puts("[FAIL] #{name}")
        IO.puts("  Error: #{inspect(reason)}\n")
        {:error, reason}
    end
  end

  def section(title) do
    IO.puts("\n--- #{title} ---\n")
  end

  def time(name, fun) do
    {time_us, result} = :timer.tc(fun)
    IO.puts("  #{name}: #{Float.round(time_us / 1000, 2)}ms")
    result
  end
end

# Get or refresh access token
TestHelper.section("Token Management")

access_token =
  if config[:access_token] do
    IO.puts("Using provided access token")
    config[:access_token]
  else
    IO.puts("Refreshing access token...")

    case Token.refresh_access_token(config[:refresh_token], :crm, region: config[:region]) do
      {:ok, %{"access_token" => token}} ->
        IO.puts("[PASS] Token refreshed successfully")
        token

      {:error, reason} ->
        IO.puts("[FAIL] Token refresh failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

# Create base input request
base_input =
  InputRequest.new(access_token)
  |> InputRequest.with_region(config[:region])
  |> InputRequest.with_module_api_name(config[:crm][:module] || "Leads")

# =============================================================================
# TEST 1: Stream with Limit
# =============================================================================

TestHelper.section("Test 1: Stream with max_records Limit")

IO.puts("Streaming records with max_records: 50, per_page: 20")

stream_limited =
  TestHelper.time("Stream execution", fn ->
    Pagination.stream_all(base_input, &Records.get_records/1, per_page: 20, max_records: 50)
    |> Enum.to_list()
  end)

IO.puts("  Records fetched: #{length(stream_limited)}")

if length(stream_limited) > 0 do
  IO.puts("  First record: #{inspect(hd(stream_limited)["id"])}")
end

# =============================================================================
# TEST 2: Stream with Filter
# =============================================================================

TestHelper.section("Test 2: Stream with Filter (Lazy Evaluation)")

IO.puts("Taking first 10 records from stream (fetches only needed pages)")

stream_filtered =
  TestHelper.time("Take 10 records", fn ->
    Pagination.stream_all(base_input, &Records.get_records/1, per_page: 5)
    |> Enum.take(10)
  end)

IO.puts("  Records fetched: #{length(stream_filtered)}")

# =============================================================================
# TEST 3: Fetch All
# =============================================================================

TestHelper.section("Test 3: Fetch All (Eager Evaluation)")

IO.puts("Fetching all records up to max_records: 100")

case TestHelper.time("Fetch all", fn ->
       Pagination.fetch_all(base_input, &Records.get_records/1, per_page: 50, max_records: 100)
     end) do
  {:ok, records} ->
    IO.puts("  Total records: #{length(records)}")
    TestHelper.print_result("Fetch all records", {:ok, records})

  {:error, reason} ->
    TestHelper.print_result("Fetch all records", {:error, reason})
end

# =============================================================================
# TEST 4: Error Handling in Stream
# =============================================================================

TestHelper.section("Test 4: Error Handling")

IO.puts("Testing error propagation with invalid module...")

error_input =
  base_input
  |> InputRequest.with_module_api_name("InvalidModuleName")

case Pagination.fetch_all(error_input, &Records.get_records/1, max_records: 10) do
  {:ok, records} ->
    IO.puts("[UNEXPECTED] Got #{length(records)} records from invalid module")

  {:error, reason} ->
    IO.puts("[EXPECTED] Error properly propagated:")
    IO.puts("  #{inspect(reason)}")
end

# =============================================================================
# TEST 5: Single Page Fetch
# =============================================================================

TestHelper.section("Test 5: Single Page Fetch")

IO.puts("Fetching single page directly...")

case Pagination.fetch_page(base_input, &Records.get_records/1, 1, 10) do
  {:ok, records, more_records} ->
    IO.puts("[PASS] Single page fetch")
    IO.puts("  Records: #{length(records)}")
    IO.puts("  More records: #{more_records}")

  {:error, reason} ->
    IO.puts("[FAIL] Single page fetch")
    IO.puts("  Error: #{inspect(reason)}")
end

# =============================================================================
# TEST 6: Stream with reduce_while for Error Handling
# =============================================================================

TestHelper.section("Test 6: Stream with reduce_while Pattern")

IO.puts("Demonstrating error handling pattern with reduce_while...")

result =
  Pagination.stream_all(base_input, &Records.get_records/1, per_page: 10, max_records: 30)
  |> Enum.reduce_while({:ok, []}, fn
    {:error, reason} ->
      IO.puts("  Encountered error: #{inspect(reason)}")
      {:halt, {:error, reason}}

    record, {:ok, acc} ->
      {:cont, {:ok, [record | acc]}}
  end)

case result do
  {:ok, records} ->
    IO.puts("[PASS] Processed #{length(records)} records without errors")

  {:error, reason} ->
    IO.puts("[FAIL] Stream halted due to error: #{inspect(reason)}")
end

IO.puts("\n=== Pagination Test Complete ===")
