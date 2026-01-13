defmodule ZohoAPI.Modules.CRM.Composite do
  @moduledoc """
  Zoho CRM Composite API.

  The Composite API allows you to execute multiple API requests in a single call.
  You can combine up to 5 different API operations (GET, POST, PUT, DELETE)
  and execute them together.

  ## Features

    - Execute up to 5 API calls in a single request
    - Mix different HTTP methods (GET, POST, PUT, DELETE)
    - Each sub-request can target different modules
    - Responses are returned in the same order as requests

  ## Examples

      # Execute multiple operations in one call
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "__composite_requests" => [
          %{
            "method" => "GET",
            "reference_id" => "leads_list",
            "url" => "/crm/v8/Leads"
          },
          %{
            "method" => "POST",
            "reference_id" => "create_contact",
            "url" => "/crm/v8/Contacts",
            "body" => %{
              "data" => [%{"Last_Name" => "New Contact"}]
            }
          }
        ]
      })

      {:ok, result} = Composite.execute(input)
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @doc """
  Executes multiple API requests in a single call.

  ## Parameters

    - `input` - InputRequest with `body` containing `__composite_requests` array

  ## Body Format

  The body should contain a `__composite_requests` array with up to 5 requests:

      %{
        "__composite_requests" => [
          %{
            "method" => "GET" | "POST" | "PUT" | "DELETE",
            "reference_id" => "unique_reference",
            "url" => "/crm/v8/ModuleName",
            "body" => %{...}  # Optional, for POST/PUT
          }
        ]
      }

  ## Returns

    - `{:ok, %{"__composite_responses" => [...]}}` on success
    - `{:error, reason}` on failure
  """
  @max_composite_requests 5
  @valid_methods ["GET", "POST", "PUT", "DELETE"]

  @spec execute(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def execute(%InputRequest{} = r) do
    with :ok <- validate_composite_requests(r.body) do
      Request.new("composite")
      |> Request.set_access_token(r.access_token)
      |> Request.with_params(r.query_params)
      |> Request.with_body(r.body)
      |> Request.with_method(:post)
      |> Request.send()
    end
  end

  defp validate_composite_requests(%{"__composite_requests" => []}),
    do: {:error, "At least one composite request is required"}

  defp validate_composite_requests(%{"__composite_requests" => requests})
       when is_list(requests) do
    count = length(requests)

    if count > @max_composite_requests do
      {:error,
       "Composite API supports a maximum of #{@max_composite_requests} requests, got #{count}"}
    else
      validate_each_request(requests)
    end
  end

  defp validate_composite_requests(_) do
    {:error, "Body must contain __composite_requests array"}
  end

  defp validate_each_request(requests) do
    # First validate each individual request (including type check)
    case validate_all_requests(requests) do
      :ok ->
        # Then check for duplicate reference_ids (only after we know all are maps)
        reference_ids = Enum.map(requests, &Map.get(&1, "reference_id"))

        if length(reference_ids) != length(Enum.uniq(reference_ids)) do
          {:error, "Duplicate reference_id found. Each request must have a unique reference_id"}
        else
          :ok
        end

      {:error, _} = error ->
        error
    end
  end

  defp validate_all_requests(requests) do
    requests
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {request, index}, _acc ->
      case validate_single_request(request, index) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_single_request(request, index) when is_map(request) do
    with :ok <- validate_required_field(request, "method", index),
         :ok <- validate_required_field(request, "reference_id", index),
         :ok <- validate_required_field(request, "url", index),
         :ok <- validate_method(request["method"], index),
         :ok <- validate_non_empty_string(request["reference_id"], "reference_id", index) do
      validate_non_empty_string(request["url"], "url", index)
    end
  end

  defp validate_single_request(_, index) do
    {:error, "Request #{index}: must be a map"}
  end

  defp validate_required_field(request, field, index) do
    if Map.has_key?(request, field) do
      :ok
    else
      {:error, "Request #{index}: missing required field '#{field}'"}
    end
  end

  defp validate_method(method, index) when is_binary(method) do
    if String.upcase(method) in @valid_methods do
      :ok
    else
      {:error,
       "Request #{index}: invalid method '#{method}'. Must be one of: #{Enum.join(@valid_methods, ", ")}"}
    end
  end

  defp validate_method(_, index) do
    {:error, "Request #{index}: method must be a string"}
  end

  defp validate_non_empty_string(value, field, index) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, "Request #{index}: #{field} must be a non-empty string"}
    else
      :ok
    end
  end

  defp validate_non_empty_string(_, field, index) do
    {:error, "Request #{index}: #{field} must be a non-empty string"}
  end

  @doc """
  Builds a composite request item.

  Helper function to construct properly formatted composite request items.

  ## Parameters

    - `method` - HTTP method (:get, :post, :put, :delete)
    - `reference_id` - Unique identifier for this request
    - `url` - API endpoint URL (e.g., "/crm/v8/Leads")
    - `opts` - Optional keyword list with `:body` for POST/PUT requests

  ## Examples

      Composite.build_request(:get, "get_leads", "/crm/v8/Leads")
      Composite.build_request(:post, "create_lead", "/crm/v8/Leads",
        body: %{"data" => [%{"Last_Name" => "Test"}]}
      )
  """
  @spec build_request(atom(), String.t(), String.t(), keyword()) :: map()
  def build_request(method, reference_id, url, opts \\ []) do
    base = %{
      "method" => method |> Atom.to_string() |> String.upcase(),
      "reference_id" => reference_id,
      "url" => url
    }

    case Keyword.get(opts, :body) do
      nil -> base
      body -> Map.put(base, "body", body)
    end
  end
end
