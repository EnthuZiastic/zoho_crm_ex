defmodule ZohoCrm.Modules.Desk.Tickets do
  @moduledoc """
  Zoho Desk Tickets API.

  This module handles ticket operations for Zoho Desk help desk software.

  ## Requirements

  All Desk API calls require an organization ID (`org_id`) to be set
  in the InputRequest using `with_org_id/2`.

  ## Examples

      # List all tickets
      input = InputRequest.new("access_token")
      |> InputRequest.with_org_id("org_123")

      {:ok, tickets} = Tickets.list_tickets(input)

      # Create a new ticket
      input = InputRequest.new("access_token")
      |> InputRequest.with_org_id("org_123")
      |> InputRequest.with_body(%{
        "subject" => "Help needed",
        "departmentId" => "dept_123",
        "contactId" => "contact_123"
      })

      {:ok, ticket} = Tickets.create_ticket(input)
  """

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Request

  @doc """
  Lists all tickets.

  ## Parameters

    - `input` - InputRequest with `org_id` set

  ## Query Parameters (optional)

    - `from` - Starting index for pagination
    - `limit` - Number of records to return (max 100)
    - `departmentId` - Filter by department
    - `assignee` - Filter by assignee

  ## Returns

    - `{:ok, %{"data" => [tickets]}}` on success
  """
  @spec list_tickets(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def list_tickets(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("tickets")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Gets a specific ticket by ID.

  ## Parameters

    - `input` - InputRequest with `org_id` set
    - `ticket_id` - The ticket ID
  """
  @spec get_ticket(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_ticket(%InputRequest{} = r, ticket_id) do
    construct_request(r)
    |> Request.with_path("tickets/#{ticket_id}")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Creates a new ticket.

  ## Parameters

    - `input` - InputRequest with `org_id` and `body` containing:
      - `subject` - Ticket subject (required)
      - `departmentId` - Department ID (required)
      - `contactId` - Contact ID (required)
      - Other optional fields

  ## Returns

    - `{:ok, ticket}` on success
  """
  @spec create_ticket(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def create_ticket(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("tickets")
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Updates an existing ticket.

  ## Parameters

    - `input` - InputRequest with `org_id` and `body` containing fields to update
    - `ticket_id` - The ticket ID
  """
  @spec update_ticket(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def update_ticket(%InputRequest{} = r, ticket_id) do
    construct_request(r)
    |> Request.with_path("tickets/#{ticket_id}")
    |> Request.with_method(:patch)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Deletes a ticket.

  ## Parameters

    - `input` - InputRequest with `org_id` set
    - `ticket_id` - The ticket ID to delete
  """
  @spec delete_ticket(InputRequest.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def delete_ticket(%InputRequest{} = r, ticket_id) do
    construct_request(r)
    |> Request.with_path("tickets/#{ticket_id}")
    |> Request.with_method(:delete)
    |> Request.send()
  end

  @doc """
  Searches for tickets.

  ## Parameters

    - `input` - InputRequest with `org_id` and `query_params` containing:
      - `searchStr` - Search string

  ## Returns

    - `{:ok, %{"data" => [tickets]}}` on success
  """
  @spec search_tickets(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def search_tickets(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_path("tickets/search")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Lists all threads (conversations) for a ticket.

  ## Parameters

    - `input` - InputRequest with `org_id` set
    - `ticket_id` - The ticket ID
  """
  @spec list_threads(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def list_threads(%InputRequest{} = r, ticket_id) do
    construct_request(r)
    |> Request.with_path("tickets/#{ticket_id}/threads")
    |> Request.with_method(:get)
    |> Request.send()
  end

  @doc """
  Adds a comment to a ticket.

  ## Parameters

    - `input` - InputRequest with `org_id` and `body` containing:
      - `content` - Comment content
      - `isPublic` - Boolean indicating if comment is public
    - `ticket_id` - The ticket ID
  """
  @spec add_comment(InputRequest.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def add_comment(%InputRequest{} = r, ticket_id) do
    construct_request(r)
    |> Request.with_path("tickets/#{ticket_id}/comments")
    |> Request.with_method(:post)
    |> Request.with_body(r.body)
    |> Request.send()
  end

  defp construct_request(%InputRequest{org_id: nil}) do
    raise ArgumentError, "org_id is required for Zoho Desk API"
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new("desk")
    |> Request.with_version("v1")
    |> Request.set_access_token(ir.access_token)
    |> Request.set_org_id(ir.org_id)
    |> Request.with_params(ir.query_params)
  end
end
