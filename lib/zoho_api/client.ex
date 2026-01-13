defmodule ZohoAPI.Client do
  @moduledoc """
  High-level client that orchestrates request execution with advanced features.

  This module provides a unified interface for sending requests with:
  - **Token auto-refresh** - Automatically refreshes access tokens on 401 responses
  - **Retry logic** - Exponential backoff for transient failures
  - **Rate limiting** - Optional integration with PostgreSQL-backed rate limiter

  ## Execution Order

  When a request is sent through the Client:
  1. Rate limiting (if enabled) - queues request to respect API limits
  2. Retry logic - retries on network errors and 5xx responses
  3. Token refresh - on 401, refreshes token and retries once

  ## Usage

  The Client is typically used internally by API modules, but can be called directly:

      request = Request.new("crm")
      |> Request.set_access_token(access_token)
      |> Request.with_method(:get)
      |> Request.with_path("Leads")

      input = InputRequest.new(access_token)
      |> InputRequest.with_refresh_token(refresh_token)

      {:ok, data} = Client.send(request, input)

  ## Configuration

  Configure global defaults in `config.exs`:

      # Retry settings
      config :zoho_api, :retry,
        enabled: true,
        max_retries: 3,
        base_delay_ms: 1000

      # Rate limiter settings (optional)
      config :zoho_api, :rate_limiter,
        enabled: false,
        repo: nil
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Token
  alias ZohoAPI.RateLimiter
  alias ZohoAPI.Request
  alias ZohoAPI.Retry

  @doc """
  Send a request with full feature support.

  Executes the request through rate limiting, retry logic, and token refresh
  as configured in the InputRequest and global settings.

  ## Parameters

    - `request` - The built Request struct
    - `input` - The InputRequest with configuration options

  ## Returns

    - `{:ok, data}` - Successful response (2xx)
    - `{:error, data}` - Error response (non-2xx or failure)
    - `{:error, :token_refresh_failed}` - Token refresh failed on 401

  ## Examples

      request = Request.new("crm")
      |> Request.set_access_token("token")
      |> Request.with_method(:get)
      |> Request.with_path("Leads")

      input = InputRequest.new("token")
      |> InputRequest.with_refresh_token("refresh_token")

      {:ok, leads} = Client.send(request, input)
  """
  @spec send(Request.t(), InputRequest.t()) :: {:ok, any()} | {:error, any()}
  def send(%Request{} = request, %InputRequest{} = input) do
    request_fn = fn -> execute_with_retry(request, input) end

    result = RateLimiter.execute(request_fn, input.rate_limit_opts || [])
    format_response(result)
  end

  @doc """
  Send a request without rate limiting.

  Useful when you want retry and token refresh but are handling rate limiting
  externally or don't need it.

  ## Parameters

    - `request` - The built Request struct
    - `input` - The InputRequest with configuration options

  ## Returns

    Same as `send/2`
  """
  @spec send_without_rate_limit(Request.t(), InputRequest.t()) :: {:ok, any()} | {:error, any()}
  def send_without_rate_limit(%Request{} = request, %InputRequest{} = input) do
    result = execute_with_retry(request, input)
    format_response(result)
  end

  # Private functions

  defp execute_with_retry(request, input) do
    retry_opts = input.retry_opts || []

    Retry.with_retry(
      fn ->
        case Request.send_raw(request) do
          {:ok, 401, _body} = unauthorized ->
            handle_401(request, input, unauthorized)

          other ->
            other
        end
      end,
      retry_opts
    )
  end

  defp handle_401(request, input, original_error) do
    if is_nil(input.refresh_token) do
      original_error
    else
      do_token_refresh(request, input)
    end
  end

  defp do_token_refresh(request, input) do
    service = api_type_to_service(request.api_type)

    case Token.refresh_access_token(input.refresh_token, service: service, region: input.region) do
      {:ok, %{"access_token" => new_token}} ->
        notify_token_refresh(input.on_token_refresh, new_token)
        updated_request = Request.set_access_token(request, new_token)
        Request.send_raw(updated_request)

      {:ok, response} ->
        {:error, {:token_refresh_unexpected, response}}

      {:error, _reason} ->
        {:error, :token_refresh_failed}
    end
  end

  defp notify_token_refresh(nil, _token), do: :ok

  defp notify_token_refresh(callback, token) do
    callback.(token)
  rescue
    # Don't fail the request if callback fails
    _ -> :ok
  end

  @api_type_to_service_map %{
    "crm" => :crm,
    "bulk" => :crm,
    "composite" => :crm,
    "desk" => :desk,
    "workdrive" => :workdrive,
    "recruit" => :recruit,
    "bookings" => :bookings,
    "portal" => :projects
  }

  defp api_type_to_service(api_type) do
    Map.get(@api_type_to_service_map, api_type, :crm)
  end

  defp format_response({:ok, status_code, body}) when status_code in 200..299 do
    {:ok, body}
  end

  defp format_response({:ok, _status_code, body}) do
    {:error, body}
  end

  defp format_response({:error, _reason} = error) do
    error
  end
end
