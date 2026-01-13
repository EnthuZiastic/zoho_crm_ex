#!/usr/bin/env elixir
# Test script for Zoho Desk API
#
# Usage:
#   mix run scripts/test_desk.exs
#
# Requirements:
#   - Zoho Desk API access (separate OAuth scope from CRM)
#   - Organization ID
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
alias ZohoAPI.Modules.Desk
alias ZohoAPI.Modules.Token

IO.puts("=== Zoho Desk API Test Script ===\n")

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

# Validate Desk configuration
unless config[:desk][:org_id] do
  IO.puts("[ERROR] Desk org_id is required in config.exs")
  System.halt(1)
end

# Get or refresh access token
TestHelper.section("Token Management")

access_token =
  if config[:access_token] do
    IO.puts("Using provided access token")
    config[:access_token]
  else
    IO.puts("Refreshing access token...")

    case Token.refresh_access_token(config[:refresh_token], :desk, region: config[:region]) do
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

# Test 1: Get Organization Details
TestHelper.section("Organization")

org_input =
  base_input
  |> InputRequest.with_org_id(config[:desk][:org_id])

TestHelper.print_result("Get organization info", Desk.get_organization(org_input))

# Test 2: List Departments
TestHelper.section("Departments")

dept_input =
  base_input
  |> InputRequest.with_org_id(config[:desk][:org_id])

TestHelper.print_result("List departments", Desk.list_departments(dept_input))

# Test 3: List Tickets
TestHelper.section("Tickets")

ticket_input =
  base_input
  |> InputRequest.with_org_id(config[:desk][:org_id])
  |> InputRequest.with_query_params(%{"limit" => 5})

TestHelper.print_result("List tickets (5 max)", Desk.list_tickets(ticket_input))

# Test 4: Get Ticket (if department_id provided)
if config[:desk][:department_id] do
  TestHelper.section("Department Tickets")

  dept_ticket_input =
    base_input
    |> InputRequest.with_org_id(config[:desk][:org_id])
    |> InputRequest.with_query_params(%{
      "departmentId" => config[:desk][:department_id],
      "limit" => 5
    })

  TestHelper.print_result(
    "List tickets for department #{config[:desk][:department_id]}",
    Desk.list_tickets(dept_ticket_input)
  )
end

# Test 5: List Agents
TestHelper.section("Agents")

agent_input =
  base_input
  |> InputRequest.with_org_id(config[:desk][:org_id])
  |> InputRequest.with_query_params(%{"limit" => 5})

TestHelper.print_result("List agents (5 max)", Desk.list_agents(agent_input))

IO.puts("\n=== Desk Test Complete ===")
