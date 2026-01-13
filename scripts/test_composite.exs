#!/usr/bin/env elixir
# Test script for Zoho CRM Composite API
#
# Usage:
#   mix run scripts/test_composite.exs
#
# The Composite API allows executing multiple API requests in a single call.
# IMPORTANT: Composite requests are NOT atomic - each sub-request runs independently.
#
# Configuration:
#   Copy scripts/config.example.exs to scripts/config.exs and fill in your values

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
alias ZohoAPI.Modules.CRM.Composite
alias ZohoAPI.Modules.Token

IO.puts("=== Zoho CRM Composite API Test Script ===\n")

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

  def analyze_composite_response(responses) do
    IO.puts("Analyzing composite response:")

    Enum.each(responses, fn response ->
      status = response["status_code"] || "unknown"
      ref_id = response["reference_id"] || "unknown"

      status_indicator =
        cond do
          status in 200..299 -> "[OK]"
          status in 400..499 -> "[CLIENT_ERROR]"
          status in 500..599 -> "[SERVER_ERROR]"
          true -> "[UNKNOWN]"
        end

      IO.puts("  #{status_indicator} #{ref_id}: HTTP #{status}")
    end)

    IO.puts("")
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

module_name = config[:crm][:module] || "Leads"

# =============================================================================
# TEST 1: Multiple GET Requests
# =============================================================================

TestHelper.section("Test 1: Multiple GET Requests")

IO.puts("Executing 3 GET requests in a single API call...")

get_requests_input =
  base_input
  |> InputRequest.with_body(%{
    "__composite_requests" => [
      Composite.build_request(:get, "get_leads", "/crm/v8/Leads?per_page=2"),
      Composite.build_request(:get, "get_contacts", "/crm/v8/Contacts?per_page=2"),
      Composite.build_request(:get, "get_deals", "/crm/v8/Deals?per_page=2")
    ]
  })

case TestHelper.print_result("Execute 3 GET requests", Composite.execute(get_requests_input)) do
  {:ok, %{"__composite_responses" => responses}} ->
    TestHelper.analyze_composite_response(responses)

  _ ->
    :ok
end

# =============================================================================
# TEST 2: Create + Read Pattern
# =============================================================================

TestHelper.section("Test 2: Create and Read Records")

IO.puts("Creating a record and listing records in a single call...")
IO.puts("NOTE: The list won't include the new record (requests run in parallel)\n")

random_suffix = :rand.uniform(10000)

create_and_read_input =
  base_input
  |> InputRequest.with_body(%{
    "__composite_requests" => [
      Composite.build_request(:post, "create_lead", "/crm/v8/#{module_name}",
        body: %{
          "data" => [
            %{
              "Last_Name" => "Composite Test #{random_suffix}",
              "Company" => "Test Company",
              "Email" => "composite.test.#{random_suffix}@example.com"
            }
          ]
        }
      ),
      Composite.build_request(:get, "list_leads", "/crm/v8/#{module_name}?per_page=3")
    ]
  })

created_id =
  case TestHelper.print_result("Create and list records", Composite.execute(create_and_read_input)) do
    {:ok, %{"__composite_responses" => responses}} ->
      TestHelper.analyze_composite_response(responses)

      # Extract created record ID for cleanup
      responses
      |> Enum.find(&(&1["reference_id"] == "create_lead"))
      |> case do
        %{"body" => %{"data" => [%{"details" => %{"id" => id}} | _]}} -> id
        _ -> nil
      end

    _ ->
      nil
  end

# =============================================================================
# TEST 3: Cleanup - Delete Created Record
# =============================================================================

if created_id do
  TestHelper.section("Test 3: Cleanup")

  IO.puts("Deleting the test record created above...")

  delete_input =
    base_input
    |> InputRequest.with_body(%{
      "__composite_requests" => [
        Composite.build_request(:delete, "delete_test", "/crm/v8/#{module_name}?ids=#{created_id}")
      ]
    })

  case TestHelper.print_result("Delete test record", Composite.execute(delete_input)) do
    {:ok, %{"__composite_responses" => responses}} ->
      TestHelper.analyze_composite_response(responses)

    _ ->
      :ok
  end
end

# =============================================================================
# TEST 4: Error Handling
# =============================================================================

TestHelper.section("Test 4: Error Handling (Invalid Request)")

IO.puts("Testing error handling with an invalid request...")

error_input =
  base_input
  |> InputRequest.with_body(%{
    "__composite_requests" => [
      Composite.build_request(:get, "valid_request", "/crm/v8/Leads?per_page=1"),
      Composite.build_request(:get, "invalid_request", "/crm/v8/NonExistentModule")
    ]
  })

case TestHelper.print_result("Mixed valid/invalid requests", Composite.execute(error_input)) do
  {:ok, %{"__composite_responses" => responses}} ->
    TestHelper.analyze_composite_response(responses)
    IO.puts("NOTE: Each request has its own status code. Check individual responses!")

  _ ->
    :ok
end

IO.puts("\n=== Composite API Test Complete ===")
