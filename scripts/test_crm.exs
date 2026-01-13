#!/usr/bin/env elixir
# Test script for Zoho CRM API
#
# Usage:
#   mix run scripts/test_crm.exs
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

  Then edit scripts/config.exs with your real API keys.
  """)

  System.halt(1)
end

config = Code.eval_file(config_path) |> elem(0)

# Configure the application with credentials from config.exs
Application.put_env(:zoho_api, :crm,
  client_id: config[:client_id],
  client_secret: config[:client_secret]
)

alias ZohoAPI.InputRequest
alias ZohoAPI.Modules.CRM.Records
alias ZohoAPI.Modules.Token
alias ZohoAPI.Client

IO.puts("=== Zoho CRM API Test Script ===\n")

# Helper to print results
defmodule TestHelper do
  def print_result(name, result) do
    case result do
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
end

# Get or refresh access token
TestHelper.section("Token Management")

access_token =
  if config[:access_token] do
    IO.puts("Using provided access token")
    config[:access_token]
  else
    IO.puts("Refreshing access token...")

    case Token.refresh_access_token(config[:refresh_token], service: :crm, region: config[:region]) do
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
  |> InputRequest.with_module_api_name(config[:crm][:module])

# Test 1: Get Records (List)
TestHelper.section("Get Records (List)")

# Note: Zoho CRM v8 requires 'fields' parameter
input = base_input |> InputRequest.with_query_params(%{"per_page" => 5, "fields" => "Last_Name,Email,Company"})
TestHelper.print_result("Get #{config[:crm][:module]} (5 records)", Records.get_records(input))

# Test 2: Search Records
TestHelper.section("Search Records")

search_input =
  base_input
  |> InputRequest.with_query_params(%{"criteria" => "(Created_Time:greater_than:2020-01-01T00:00:00+00:00)"})

TestHelper.print_result(
  "Search #{config[:crm][:module]} by Created_Time",
  Records.search_records(search_input)
)

# Test 3: Get Specific Record (if record_id provided)
if config[:crm][:record_id] do
  TestHelper.section("Get Specific Record")

  TestHelper.print_result(
    "Get record #{config[:crm][:record_id]}",
    Records.get_record(base_input, to_string(config[:crm][:record_id]))
  )
end

# Test 4: Create and Delete Record
TestHelper.section("Create Record")

create_input =
  base_input
  |> InputRequest.with_body([
    %{
      "Last_Name" => "Test User #{:rand.uniform(10000)}",
      "Company" => "Test Company",
      "Email" => "test#{:rand.uniform(10000)}@example.com"
    }
  ])

case TestHelper.print_result("Create test #{config[:crm][:module]}", Records.insert_records(create_input)) do
  {:ok, %{"data" => [%{"details" => %{"id" => record_id}} | _]}} ->
    TestHelper.section("Delete Created Record")

    delete_input =
      base_input
      |> InputRequest.with_query_params(%{"ids" => record_id})

    TestHelper.print_result("Delete record #{record_id}", Records.delete_records(delete_input))

  _ ->
    IO.puts("Skipping delete test - no record created")
end

# Test 5: Get Records with Client (includes retry logic)
TestHelper.section("Client with Retry Logic")

client_input =
  base_input
  |> InputRequest.with_query_params(%{"per_page" => 3})
  |> InputRequest.with_refresh_token(config[:refresh_token])
  |> InputRequest.with_retry_opts(max_retries: 2, base_delay_ms: 500)

request =
  ZohoAPI.Request.new("crm")
  |> ZohoAPI.Request.set_access_token(access_token)
  |> ZohoAPI.Request.with_region(config[:region])
  |> ZohoAPI.Request.with_method(:get)
  |> ZohoAPI.Request.with_path(config[:crm][:module])
  |> ZohoAPI.Request.with_params(%{"per_page" => 3, "fields" => "Last_Name,Email,Company"})

TestHelper.print_result("Client.send with retry", Client.send(request, client_input))

IO.puts("\n=== CRM Test Complete ===")
