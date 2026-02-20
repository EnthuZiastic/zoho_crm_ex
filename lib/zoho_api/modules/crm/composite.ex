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

  ## Transaction Semantics

  **Important:** Composite API requests are **NOT atomic/transactional**.

    - Each sub-request is executed independently
    - If request 3 of 5 fails, requests 1-2 may have already succeeded
    - Failed requests do not roll back previously successful requests
    - Each response in `__composite_responses` includes its own status code
    - In parallel mode (default), requests cannot reference data from earlier responses
    - In sequential mode (`parallel_execution: false`), later requests CAN reference
      earlier responses using placeholder syntax (see "Execution Control" section)

  Always check individual response status codes:

      {:ok, %{"__composite_responses" => responses}} = Composite.execute(input)

      Enum.each(responses, fn response ->
        case response["status_code"] do
          200 -> # Success
          201 -> # Created
          code -> # Handle error for this specific request
        end
      end)

  ## Execution Control

  Control parallel vs sequential execution using `parallel_execution`:

      %{
        "parallel_execution" => false,  # Set false for sequential execution (default: true = parallel)
        "__composite_requests" => [...]
      }

  **Important:** The parameter name is `parallel_execution`, NOT `concurrent_execution`.
  Using `concurrent_execution` will cause an `INVALID_REQUEST` error from Zoho.

  When `parallel_execution` is `false`, requests execute in order and later requests
  can reference results from earlier requests using placeholder syntax.

  ### Placeholder Syntax

  Placeholders use JSONPath-like syntax to reference data from earlier responses:

      @{reference_id:$.json_path}

  Where:
    - `reference_id` - The `reference_id` of the earlier request
    - `$.json_path` - JSONPath expression to extract data from that response

  Common patterns:
    - `@{search_contact:$.data[0].id}` - Get the ID from request "search_contact"
    - `@{1:$.data[0].id}` - Get the ID from request "1" (numeric reference_ids also work)
    - `@{search:$.data[0].Account_Name.id}` - Get a nested field value

  ### Error Handling in Sequential Mode

  When using sequential execution with data references, handle cases where earlier
  requests return no data (e.g., search with no results):

      # If the search returns 204 (no content), the placeholder @{1:$.data[0].id}
      # will be invalid, causing an INVALID_REFERENCE error in the second request.
      # Check for this in __composite_responses:
      case result do
        {:ok, %{"__composite_responses" => [
          %{"status_code" => 204},  # Search found nothing
          %{"code" => "INVALID_REFERENCE"}  # Reference couldn't resolve
        ]}} ->
          {:error, :not_found}

        {:ok, %{"__composite_responses" => [_, %{"status_code" => 200}]}} ->
          :ok
      end

  ## Cleanup Strategies

  If you need transactional behavior, implement cleanup logic:

      {:ok, %{"__composite_responses" => responses}} = Composite.execute(input)

      # Partition by success/failure
      {successes, failures} =
        Enum.split_with(responses, fn r ->
          r["status_code"] in 200..299
        end)

      # If any failed, clean up the successful creates
      if length(failures) > 0 do
        created_ids =
          successes
          |> Enum.filter(&(&1["body"]["data"]))
          |> Enum.flat_map(fn r ->
            Enum.map(r["body"]["data"], & &1["details"]["id"])
          end)

        if length(created_ids) > 0 do
          # Delete the partially created records
          cleanup_input = InputRequest.new(access_token)
          |> InputRequest.with_body(%{
            "__composite_requests" => [
              %{
                "method" => "DELETE",
                "reference_id" => "cleanup",
                "url" => "/crm/v8/Leads?ids=\#{Enum.join(created_ids, ",")}"
              }
            ]
          })
          Composite.execute(cleanup_input)
        end
      end

  ## Examples

      # Execute multiple operations in one call (parallel)
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

      # Sequential execution with data reference from previous request
      # Note: If search returns no results (204), the placeholder will fail with
      # INVALID_REFERENCE. See "Error Handling in Sequential Mode" above.
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "parallel_execution" => false,
        "__composite_requests" => [
          %{
            "method" => "GET",
            "reference_id" => "search_contact",
            "url" => "/crm/v8/Contacts/search",
            "params" => %{"criteria" => "(Email:equals:test@example.com)"}
          },
          %{
            "method" => "PUT",
            "reference_id" => "update_contact",
            "url" => "/crm/v8/Contacts/@{search_contact:$.data[0].id}",
            "body" => %{"data" => [%{"Phone" => "555-1234"}]}
          }
        ]
      })

      {:ok, result} = Composite.execute(input)
  """

  require Logger

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @typedoc """
  A single composite request item.

  ## Required Fields

    - `"method"` - HTTP method: "GET", "POST", "PUT", or "DELETE"
    - `"reference_id"` - Unique identifier for this request
    - `"url"` - API endpoint URL (e.g., "/crm/v8/Leads")

  ## Optional Fields

    - `"body"` - Request body for POST/PUT requests
  """
  @type composite_request :: %{
          required(String.t()) => String.t() | map(),
          optional(String.t()) => any()
        }

  @typedoc """
  A composite response item.

  ## Fields

    - `"status_code"` - HTTP status code for this sub-request
    - `"reference_id"` - The reference_id from the corresponding request
    - `"body"` - Response body
  """
  @type composite_response :: %{
          String.t() => integer() | String.t() | map()
        }

  @doc """
  Executes multiple API requests in a single call.

  ## Parameters

    - `input` - InputRequest with `body` containing `__composite_requests` array

  ## Body Format

  The body should contain a `__composite_requests` array with up to 5 requests:

      %{
        "parallel_execution" => true | false,  # Optional, default: true (parallel)
        "__composite_requests" => [
          %{
            "method" => "GET" | "POST" | "PUT" | "DELETE",
            "reference_id" => "unique_reference",
            "url" => "/crm/v8/ModuleName",
            "body" => %{...},   # Optional, for POST/PUT requests
            "params" => %{...}  # Optional, query parameters (e.g., search criteria)
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
    # Warn if module_api_name is set since it's ignored for composite requests
    if r.module_api_name do
      Logger.warning(
        "Composite.execute: module_api_name is set but will be ignored. " <>
          "Individual request paths are specified in the __composite_requests body."
      )
    end

    with :ok <- validate_composite_requests(r.body) do
      Request.new("composite")
      |> Request.set_access_token(r.access_token)
      |> Request.with_region(r.region)
      |> Request.with_params(r.query_params)
      |> Request.with_body(r.body)
      |> Request.with_method(:post)
      |> Request.send()
    end
  end

  defp validate_composite_requests(%{"__composite_requests" => []}),
    do: {:error, "At least one composite request is required"}

  defp validate_composite_requests(%{"__composite_requests" => requests} = body)
       when is_list(requests) do
    with :ok <- validate_parallel_execution(body),
         :ok <- validate_request_count(requests),
         :ok <- validate_placeholder_usage(body) do
      validate_each_request(requests)
    end
  end

  defp validate_composite_requests(_) do
    {:error, "Body must contain __composite_requests array"}
  end

  defp validate_parallel_execution(%{"parallel_execution" => value})
       when not is_boolean(value) do
    {:error, "parallel_execution must be a boolean (true or false), got: #{inspect(value)}"}
  end

  defp validate_parallel_execution(_), do: :ok

  # Validate that placeholders are not used in parallel mode (default)
  # Placeholders like @{ref:$.path} only work in sequential mode
  defp validate_placeholder_usage(%{
         "parallel_execution" => false,
         "__composite_requests" => _requests
       }) do
    :ok
  end

  defp validate_placeholder_usage(%{"__composite_requests" => requests}) do
    has_placeholders =
      Enum.any?(requests, fn
        req when is_map(req) ->
          url = Map.get(req, "url", "")
          String.contains?(url, "@{")

        _ ->
          false
      end)

    if has_placeholders do
      {:error,
       "Data reference placeholders (@{...}) can only be used with parallel_execution: false (sequential mode)"}
    else
      :ok
    end
  end

  defp validate_request_count(requests) do
    count = length(requests)

    if count > @max_composite_requests do
      {:error,
       "Composite API supports a maximum of #{@max_composite_requests} requests, got #{count}"}
    else
      :ok
    end
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
