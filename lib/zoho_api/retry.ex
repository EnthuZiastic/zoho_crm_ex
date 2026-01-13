defmodule ZohoAPI.Retry do
  @moduledoc """
  Retry logic with exponential backoff for transient failures.

  This module provides automatic retry functionality for API requests that fail
  due to transient errors. It uses exponential backoff with optional jitter
  to prevent thundering herd problems.

  ## Retryable Errors

  **Network errors** (always retried):
    - `:timeout` - Connection or receive timeout
    - `:econnrefused` - Connection refused
    - `:closed` - Connection closed
    - `:nxdomain` - DNS resolution failed
    - `:ehostunreach` - Host unreachable

  **HTTP status codes** (retried by default):
    - `429` - Too Many Requests (rate limited, respects Retry-After from response)
    - `500` - Internal Server Error
    - `502` - Bad Gateway
    - `503` - Service Unavailable
    - `504` - Gateway Timeout
    - `529` - Site Overloaded (Zoho-specific)

  ## Rate Limit Handling (429)

  When a 429 response is received, the retry logic will:
  1. Check the response body for a `retry_after` or `Retry-After` value (in seconds)
  2. If found, use that value as the delay
  3. Otherwise, fall back to exponential backoff

  **Not retried:**
    - 4xx client errors (except 429) - These indicate a problem with the request
    - Successful responses (2xx) - No retry needed

  ## Configuration

  Configure globally in your `config.exs`:

      config :zoho_api, :retry,
        enabled: true,
        max_retries: 3,
        base_delay_ms: 1000,
        max_delay_ms: 30_000,
        jitter: true

  Override per-request via `InputRequest.with_retry_opts/2`.

  ## Examples

      # Basic usage with defaults
      Retry.with_retry(fn -> Request.send_raw(request) end)

      # Custom options
      Retry.with_retry(
        fn -> Request.send_raw(request) end,
        max_retries: 5,
        base_delay_ms: 2000
      )

      # Disable retries
      Retry.with_retry(fn -> Request.send_raw(request) end, max_retries: 0)
  """

  # Maximum jitter as a fraction of delay (30%)
  @jitter_factor 0.3

  @default_config %{
    enabled: true,
    max_retries: 3,
    base_delay_ms: 1000,
    max_delay_ms: 30_000,
    jitter: true,
    retryable_network_errors: [:timeout, :econnrefused, :closed, :nxdomain, :ehostunreach],
    retryable_status_codes: [429, 500, 502, 503, 504, 529]
  }

  @type config :: %{
          enabled: boolean(),
          max_retries: non_neg_integer(),
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer(),
          jitter: boolean(),
          retryable_network_errors: [atom()],
          retryable_status_codes: [pos_integer()]
        }

  @type result :: {:ok, integer(), any()} | {:error, any()}

  @doc """
  Execute a function with retry logic.

  The function should return `{:ok, status_code, body}` for HTTP responses
  or `{:error, reason}` for connection errors (matching `Request.send_raw/1`).

  ## Parameters

    - `request_fn` - A zero-arity function that performs the request
    - `opts` - Optional keyword list to override default configuration

  ## Options

    - `:enabled` - Enable/disable retries (default: true)
    - `:max_retries` - Maximum retry attempts (default: 3)
    - `:base_delay_ms` - Initial delay in ms (default: 1000)
    - `:max_delay_ms` - Maximum delay cap in ms (default: 30000)
    - `:jitter` - Add random jitter to delay (default: true)

  ## Returns

    The result of the last attempt, whether successful or not.

  ## Examples

      result = Retry.with_retry(fn ->
        Request.send_raw(request)
      end)

      case result do
        {:ok, 200, body} -> {:ok, body}
        {:ok, status, body} -> {:error, {status, body}}
        {:error, reason} -> {:error, reason}
      end
  """
  @spec with_retry((-> result()), keyword()) :: result()
  def with_retry(request_fn, opts \\ []) do
    config = build_config(opts)

    if config.enabled and config.max_retries > 0 do
      do_retry(request_fn, config, 0)
    else
      request_fn.()
    end
  end

  @doc """
  Calculate the delay for a given attempt using exponential backoff.

  Useful for testing or custom retry logic.

  ## Examples

      iex> Retry.calculate_delay(0, 1000, 30000, false)
      1000

      iex> Retry.calculate_delay(2, 1000, 30000, false)
      4000
  """
  @spec calculate_delay(non_neg_integer(), pos_integer(), pos_integer(), boolean()) ::
          pos_integer()
  def calculate_delay(attempt, base_delay_ms, max_delay_ms, jitter) do
    # Exponential backoff: base * 2^attempt
    base = base_delay_ms * :math.pow(2, attempt)
    delay = min(round(base), max_delay_ms)

    if jitter do
      # Add up to @jitter_factor random jitter
      jitter_amount = :rand.uniform(max(1, round(delay * @jitter_factor)))
      delay + jitter_amount
    else
      delay
    end
  end

  @doc """
  Check if an error is retryable.

  ## Examples

      iex> Retry.retryable?({:error, :timeout}, config)
      true

      iex> Retry.retryable?({:ok, 500, %{}}, config)
      true

      iex> Retry.retryable?({:ok, 400, %{}}, config)
      false
  """
  @spec retryable?(result(), config()) :: boolean()
  def retryable?({:ok, status_code, _body}, config) do
    status_code in config.retryable_status_codes
  end

  def retryable?({:error, reason}, config) when is_atom(reason) do
    reason in config.retryable_network_errors
  end

  def retryable?({:error, _reason}, _config), do: false

  # Private functions

  defp build_config(opts) do
    # Start with defaults
    global_opts = Application.get_env(:zoho_api, :retry, [])
    merged_opts = Keyword.merge(Enum.to_list(global_opts), opts)

    # Build config map
    Enum.reduce(merged_opts, @default_config, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp do_retry(request_fn, config, attempt) do
    result = request_fn.()

    cond do
      # Success (2xx) - return immediately
      match?({:ok, status, _} when status in 200..299, result) ->
        result

      # Retryable error and we have attempts left
      retryable?(result, config) and attempt < config.max_retries ->
        delay = get_retry_delay(result, attempt, config)

        Process.sleep(delay)
        do_retry(request_fn, config, attempt + 1)

      # Non-retryable or out of attempts - return last result
      true ->
        result
    end
  end

  # For 429 responses, try to extract Retry-After from the response body
  defp get_retry_delay({:ok, 429, body}, _attempt, config) when is_map(body) do
    retry_after = extract_retry_after(body)

    if retry_after do
      # Convert seconds to milliseconds, cap at max_delay
      min(retry_after * 1000, config.max_delay_ms)
    else
      # Fall back to exponential backoff
      calculate_delay(0, config.base_delay_ms, config.max_delay_ms, config.jitter)
    end
  end

  defp get_retry_delay(_result, attempt, config) do
    calculate_delay(attempt, config.base_delay_ms, config.max_delay_ms, config.jitter)
  end

  # Extract retry_after from various possible response body formats
  defp extract_retry_after(body) when is_map(body) do
    # Try common keys where Retry-After might be found
    cond do
      # Direct retry_after key
      is_integer(body["retry_after"]) ->
        body["retry_after"]

      # Nested in details
      is_map(body["details"]) and is_integer(body["details"]["retry_after"]) ->
        body["details"]["retry_after"]

      # Zoho-style with different casing
      is_integer(body["Retry-After"]) ->
        body["Retry-After"]

      # String value
      is_binary(body["retry_after"]) ->
        parse_retry_after_string(body["retry_after"])

      true ->
        nil
    end
  end

  defp extract_retry_after(_), do: nil

  defp parse_retry_after_string(value) do
    case Integer.parse(value) do
      {seconds, _} when seconds > 0 -> seconds
      _ -> nil
    end
  end
end
