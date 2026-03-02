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
    - In parallel mode (default), requests cannot reference data from earlier responses
    - In sequential mode (`parallel_execution: false`), later requests CAN reference
      earlier responses using placeholder syntax (see "Execution Control" section)

  Always check individual response codes:

      {:ok, %{"__composite_responses" => responses}} = Composite.execute(input)

      Enum.each(responses, fn response ->
        case response["status_code"] do
          200 -> # Success
          201 -> # Created
          _ -> # Handle error — check response["code"] and response["body"]
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
    - `sub_request_id` - The `sub_request_id` of the earlier request (e.g. `"1"`, `"2"`)
    - `$.json_path` - JSONPath expression to extract data from that response body

  Common patterns (path is relative to the sub-request's response body):
    - `@{1:$.data[0].id}` - ID from a GET/search result
    - `@{1:$.data[0].details.id}` - ID from a POST/PUT create/update result

  ### Error Handling in Sequential Mode

  When using sequential execution with data references, handle cases where earlier
  requests return no data (e.g., search with no results):

      # If the search returns 204 (no content), the placeholder @{1:$.data[0].id}
      # will be invalid, causing an INVALID_REFERENCE error in the second request.
      case result do
        {:ok, %{"__composite_responses" => [
          %{"code" => "NO_CONTENT"},  # Search found nothing
          %{"code" => "INVALID_REFERENCE"}  # Reference couldn't resolve
        ]}} ->
          {:error, :not_found}

        {:ok, %{"__composite_responses" => [_, %{"status_code" => code}]}} when code in 200..299 ->
          :ok
      end

  ## Response Format

  `execute/1` normalizes Zoho's raw response into a consistent format.
  Each item in `__composite_responses` has:

    - `"code"` - `"SUCCESS"` on success, or an error code (e.g. `"INVALID_REFERENCE"`)
    - `"status_code"` - HTTP status code for this sub-request (nil on error)
    - `"body"` - response body map (nil on error)

  ## Examples

      # Execute multiple operations in one call (parallel)
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "__composite_requests" => [
          %{
            "method" => "GET",
            "sub_request_id" => "1",
            "uri" => "/crm/v8/Leads"
          },
          %{
            "method" => "POST",
            "sub_request_id" => "2",
            "uri" => "/crm/v8/Contacts",
            "body" => %{
              "data" => [%{"Last_Name" => "New Contact"}]
            }
          }
        ]
      })

      {:ok, result} = Composite.execute(input)

      # Sequential execution with data reference from previous request
      input = InputRequest.new("access_token")
      |> InputRequest.with_body(%{
        "parallel_execution" => false,
        "__composite_requests" => [
          %{
            "method" => "POST",
            "sub_request_id" => "1",
            "uri" => "/crm/v8/Leads",
            "body" => %{"data" => [%{"Last_Name" => "Boyle"}]}
          },
          %{
            "method" => "PUT",
            "sub_request_id" => "2",
            "uri" => "/crm/v8/Leads/@{1:$.data[0].details.id}",
            "body" => %{"data" => [%{"Company" => "ABC"}]}
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
    - `"sub_request_id"` - Unique identifier for this request (used in placeholder references)
    - `"uri"` - API endpoint path (e.g., "/crm/v8/Leads")

  ## Optional Fields

    - `"body"` - Request body for POST/PUT requests
    - `"params"` - Query parameters map
  """
  @type composite_request :: %{
          required(String.t()) => String.t() | map(),
          optional(String.t()) => any()
        }

  @typedoc """
  A normalized composite response item.

  ## Fields

    - `"code"` - `"SUCCESS"` on success, or error code string
    - `"status_code"` - HTTP status code for this sub-request (nil on error)
    - `"body"` - Response body map (nil on error)
  """
  @type composite_response :: %{String.t() => integer() | String.t() | map() | nil}

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
            "sub_request_id" => "unique_id",
            "uri" => "/crm/v8/ModuleName",
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

    with :ok <- validate_composite_requests(r.body),
         {:ok, raw_response} <-
           Request.new("composite")
           |> Request.set_access_token(r.access_token)
           |> Request.with_region(r.region)
           |> Request.with_params(r.query_params)
           |> Request.with_body(r.body)
           |> Request.with_method(:post)
           |> Request.send() do
      {:ok, normalize_response(raw_response)}
    end
  end

  # Zoho returns results under "__composite_requests" key with nested response info.
  # Normalize each item to %{"code", "status_code", "body"} for consistent access.
  defp normalize_response(%{"__composite_requests" => responses}) when is_list(responses) do
    %{"__composite_responses" => Enum.map(responses, &normalize_sub_response/1)}
  end

  defp normalize_response(other), do: other

  defp normalize_sub_response(%{
         "code" => "SUCCESS",
         "details" => %{"response" => %{"body" => body, "status_code" => status_code}}
       }) do
    %{"code" => "SUCCESS", "status_code" => status_code, "body" => body}
  end

  defp normalize_sub_response(%{"code" => code} = response) do
    %{"code" => code, "status_code" => nil, "body" => nil, "details" => response["details"]}
  end

  defp normalize_sub_response(response), do: response

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
          uri = Map.get(req, "uri", "")
          body = req |> Map.get("body", %{}) |> inspect()
          String.contains?(uri, "@{") or String.contains?(body, "@{")

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
        # Then check for duplicate sub_request_ids (only after we know all are maps)
        sub_request_ids = Enum.map(requests, &Map.get(&1, "sub_request_id"))

        if length(sub_request_ids) != length(Enum.uniq(sub_request_ids)) do
          {:error,
           "Duplicate sub_request_id found. Each request must have a unique sub_request_id"}
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
         :ok <- validate_required_field(request, "sub_request_id", index),
         :ok <- validate_required_field(request, "uri", index),
         :ok <- validate_method(request["method"], index),
         :ok <- validate_non_empty_string(request["sub_request_id"], "sub_request_id", index) do
      validate_non_empty_string(request["uri"], "uri", index)
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
    - `sub_request_id` - Unique identifier for this request (used in placeholder references as `@{id:$.path}`)
    - `uri` - API endpoint path (e.g., "/crm/v8/Leads")
    - `opts` - Optional keyword list with `:body` for POST/PUT requests and `:params` for query params

  ## Examples

      Composite.build_request(:get, "1", "/crm/v8/Leads")
      Composite.build_request(:post, "1", "/crm/v8/Leads",
        body: %{"data" => [%{"Last_Name" => "Test"}]}
      )
      # Reference earlier result via placeholder:
      Composite.build_request(:put, "2", "/crm/v8/Leads/@{1:$.data[0].details.id}",
        body: %{"data" => [%{"Company" => "ABC"}]}
      )
  """
  @spec build_request(atom(), String.t(), String.t(), keyword()) :: map()
  def build_request(method, sub_request_id, uri, opts \\ []) do
    base = %{
      "method" => method |> Atom.to_string() |> String.upcase(),
      "sub_request_id" => sub_request_id,
      "uri" => uri
    }

    base
    |> maybe_put_opt("body", Keyword.get(opts, :body))
    |> maybe_put_opt("params", Keyword.get(opts, :params))
  end

  defp maybe_put_opt(map, _key, nil), do: map
  defp maybe_put_opt(map, key, value), do: Map.put(map, key, value)
end
