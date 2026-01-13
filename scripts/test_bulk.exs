#!/usr/bin/env elixir
# Test script for Zoho CRM Bulk API
#
# Usage:
#   mix run scripts/test_bulk.exs
#
# Requirements:
#   - Zoho CRM API access with bulk permissions
#   - Optional: CSV file for bulk write test
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
alias ZohoAPI.Modules.CRM.BulkRead
alias ZohoAPI.Modules.CRM.BulkWrite
alias ZohoAPI.Modules.Token

IO.puts("=== Zoho CRM Bulk API Test Script ===\n")

# Helper to print results
defmodule TestHelper do
  def print_result(name, result) do
    case result do
      {:ok, data} ->
        IO.puts("[PASS] #{name}")
        IO.puts("  Response: #{inspect(data, limit: 5, pretty: true)}\n")
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

  def wait_for_job(input, job_id, check_fn, max_attempts \\ 30) do
    IO.puts("Waiting for job #{job_id}...")

    Enum.reduce_while(1..max_attempts, nil, fn attempt, _acc ->
      Process.sleep(2000)

      case check_fn.(input, job_id) do
        {:ok, %{"status" => status} = result} when status in ["COMPLETED", "FAILED"] ->
          IO.puts("  Job #{status} after #{attempt * 2} seconds")
          {:halt, {:ok, result}}

        {:ok, %{"status" => status}} ->
          IO.puts("  Attempt #{attempt}: #{status}")
          {:cont, nil}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
    |> case do
      nil -> {:error, "Timeout waiting for job"}
      result -> result
    end
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

module_name = config[:bulk][:module] || "Leads"

# =============================================================================
# BULK READ TESTS
# =============================================================================

TestHelper.section("Bulk Read - Create Job")

bulk_read_input =
  base_input
  |> InputRequest.with_body(%{
    "query" => %{
      "module" => %{"api_name" => module_name},
      "fields" => [
        %{"api_name" => "id"},
        %{"api_name" => "Last_Name"},
        %{"api_name" => "Email"},
        %{"api_name" => "Created_Time"}
      ],
      "criteria" => %{
        "group" => [
          %{
            "api_name" => "Created_Time",
            "comparator" => "greater_than",
            "value" => "2020-01-01T00:00:00+00:00"
          }
        ],
        "group_operator" => "and"
      }
    }
  })

case TestHelper.print_result("Create bulk read job", BulkRead.create_job(bulk_read_input)) do
  {:ok, %{"details" => %{"id" => job_id}}} ->
    TestHelper.section("Bulk Read - Check Status")

    # Wait for job completion
    case TestHelper.wait_for_job(base_input, job_id, &BulkRead.get_job_status/2) do
      {:ok, %{"status" => "COMPLETED", "result" => result}} ->
        IO.puts("  Records exported: #{result["count"]}")

        if result["download_url"] do
          IO.puts("  Download URL: #{result["download_url"]}")
        end

      {:ok, %{"status" => "FAILED"} = result} ->
        IO.puts("  Job failed: #{inspect(result)}")

      {:error, reason} ->
        IO.puts("  Error: #{inspect(reason)}")
    end

  _ ->
    IO.puts("Skipping job status check - no job created")
end

# =============================================================================
# BULK WRITE TESTS
# =============================================================================

if config[:bulk][:csv_file_path] && File.exists?(config[:bulk][:csv_file_path]) do
  TestHelper.section("Bulk Write - Upload File")

  csv_content = File.read!(config[:bulk][:csv_file_path])

  upload_input =
    base_input
    |> InputRequest.with_body(csv_content)

  case TestHelper.print_result("Upload CSV file", BulkWrite.upload_file(upload_input, module_name)) do
    {:ok, %{"details" => %{"file_id" => file_id}}} ->
      TestHelper.section("Bulk Write - Create Job")

      job_input =
        base_input
        |> InputRequest.with_body(%{
          "operation" => "insert",
          "resource" => [
            %{
              "type" => "data",
              "module" => %{"api_name" => module_name},
              "file_id" => file_id,
              "field_mappings" => [
                %{"api_name" => "Last_Name", "index" => 0},
                %{"api_name" => "Email", "index" => 1}
              ]
            }
          ]
        })

      case TestHelper.print_result("Create bulk write job", BulkWrite.create_job(job_input)) do
        {:ok, %{"details" => %{"id" => job_id}}} ->
          TestHelper.section("Bulk Write - Check Status")
          TestHelper.wait_for_job(base_input, job_id, &BulkWrite.get_job_status/2)

        _ ->
          IO.puts("Skipping job status check - no job created")
      end

    _ ->
      IO.puts("Skipping bulk write job - file upload failed")
  end
else
  TestHelper.section("Bulk Write")
  IO.puts("[SKIP] No CSV file configured for bulk write test")
  IO.puts("       Set bulk.csv_file_path in config.exs to test bulk write")
end

IO.puts("\n=== Bulk API Test Complete ===")
