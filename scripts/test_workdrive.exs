#!/usr/bin/env elixir
# Test script for Zoho WorkDrive API
#
# Usage:
#   mix run scripts/test_workdrive.exs
#
# Requirements:
#   - Zoho WorkDrive API access (separate OAuth scope from CRM)
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
alias ZohoAPI.Modules.WorkDrive
alias ZohoAPI.Modules.Token

IO.puts("=== Zoho WorkDrive API Test Script ===\n")

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

    # WorkDrive uses same OAuth as CRM typically
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

# Test 1: Get Current User Info
TestHelper.section("Current User")

TestHelper.print_result("Get current user info", WorkDrive.get_current_user(base_input))

# Test 2: List Teams
TestHelper.section("Teams")

TestHelper.print_result("List teams", WorkDrive.list_teams(base_input))

# Test 3: List Team Folders (if team_folder_id provided)
if config[:workdrive][:team_folder_id] do
  TestHelper.section("Team Folder Contents")

  folder_input =
    base_input
    |> InputRequest.with_query_params(%{"parent_id" => config[:workdrive][:team_folder_id]})

  TestHelper.print_result(
    "List files in folder #{config[:workdrive][:team_folder_id]}",
    WorkDrive.list_files(folder_input)
  )
end

# Test 4: List Recent Files
TestHelper.section("Recent Files")

recent_input =
  base_input
  |> InputRequest.with_query_params(%{"limit" => 5})

TestHelper.print_result("List recent files (5 max)", WorkDrive.list_recent_files(recent_input))

IO.puts("\n=== WorkDrive Test Complete ===")
