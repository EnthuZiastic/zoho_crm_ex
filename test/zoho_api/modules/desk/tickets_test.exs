defmodule ZohoAPI.Modules.Desk.TicketsTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Desk.Tickets

  setup :verify_on_exit!

  describe "list_tickets/1" do
    test "lists tickets with org_id header" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, headers ->
        assert url =~ "desk.zoho.in/api/v1/tickets"
        assert {"orgId", "org_123"} in headers
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "ticket_1"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")

      {:ok, result} = Tickets.list_tickets(input)

      assert result["data"] == [%{"id" => "ticket_1"}]
    end
  end

  describe "get_ticket/2" do
    test "gets a specific ticket" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, headers ->
        assert url =~ "tickets/ticket_123"
        assert {"orgId", "org_123"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"id" => "ticket_123", "subject" => "Test"})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")

      {:ok, result} = Tickets.get_ticket(input, "ticket_123")

      assert result["subject"] == "Test"
    end
  end

  describe "create_ticket/1" do
    test "creates a new ticket" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers ->
        assert url =~ "desk.zoho.in/api/v1/tickets"
        assert {"orgId", "org_123"} in headers

        body_map = Jason.decode!(body)
        assert body_map["subject"] == "Help needed"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body: Jason.encode!(%{"id" => "ticket_new", "subject" => "Help needed"})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")
        |> InputRequest.with_body(%{
          "subject" => "Help needed",
          "departmentId" => "dept_123",
          "contactId" => "contact_123"
        })

      {:ok, result} = Tickets.create_ticket(input)

      assert result["id"] == "ticket_new"
    end
  end

  describe "update_ticket/2" do
    test "updates an existing ticket" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :patch, url, body, _headers ->
        assert url =~ "tickets/ticket_123"
        body_map = Jason.decode!(body)
        assert body_map["status"] == "Closed"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"id" => "ticket_123", "status" => "Closed"})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")
        |> InputRequest.with_body(%{"status" => "Closed"})

      {:ok, result} = Tickets.update_ticket(input, "ticket_123")

      assert result["status"] == "Closed"
    end
  end

  describe "delete_ticket/2" do
    test "deletes a ticket" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :delete, url, _body, _headers ->
        assert url =~ "tickets/ticket_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 204,
           body: ""
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")

      {:ok, _result} = Tickets.delete_ticket(input, "ticket_123")
    end
  end

  describe "search_tickets/1" do
    test "searches for tickets" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "tickets/search"
        assert url =~ "searchStr=help"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "ticket_1"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_org_id("org_123")
        |> InputRequest.with_query_params(%{searchStr: "help"})

      {:ok, result} = Tickets.search_tickets(input)

      assert length(result["data"]) == 1
    end
  end

  describe "error handling" do
    test "raises error when org_id is missing" do
      input = InputRequest.new("test_token")

      assert_raise ArgumentError, "org_id is required for Zoho Desk API", fn ->
        Tickets.list_tickets(input)
      end
    end
  end
end
