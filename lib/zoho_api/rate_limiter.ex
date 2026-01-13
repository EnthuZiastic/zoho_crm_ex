defmodule ZohoAPI.RateLimiter do
  @moduledoc """
  Rate limiter integration for Zoho API requests.

  This module provides optional integration with PostgreSQL-backed rate limiting
  using the `rate_limiter` library (https://github.com/Enthuziastic/rate_limiter).

  ## Why Rate Limiting?

  Zoho APIs have rate limits that vary by plan and service. Exceeding these limits
  results in 429 (Too Many Requests) responses. This module helps you stay within
  limits by queueing requests and executing them at a controlled rate.

  ## Requirements

  To use rate limiting, you need:
  1. The `rate_limiter` dependency installed
  2. An Ecto repo with the rate_limiter migrations run
  3. Configuration in your `config.exs`

  ## Configuration

      config :zoho_api, :rate_limiter,
        enabled: true,
        repo: MyApp.Repo,
        key: "zoho_api",           # Default rate limit bucket
        request_count: 100,        # Max requests per time window
        time_window: 60,           # Time window in seconds
        safety_margin: 0.2         # Stay 20% under limit

  ## Usage

  Rate limiting is automatically applied when using `Client.send/2`:

      # Uses global config
      Client.send(request, input)

      # Override per-request
      input = InputRequest.new("token")
      |> InputRequest.with_rate_limit_opts(key: "zoho:priority")

      Client.send(request, input)

  ## Disabling Rate Limiting

  Rate limiting can be disabled:
  - Globally: Set `enabled: false` in config
  - Per-request: `InputRequest.with_rate_limit_opts(enabled: false)`
  - Automatically: If `repo` is not configured or `rate_limiter` is not available
  """

  @default_config %{
    enabled: false,
    repo: nil,
    key: "zoho_api",
    request_count: 100,
    time_window: 60,
    safety_margin: 0.2,
    max_retries: 3
  }

  @type config :: %{
          enabled: boolean(),
          repo: module() | nil,
          key: String.t(),
          request_count: pos_integer(),
          time_window: pos_integer(),
          safety_margin: float(),
          max_retries: non_neg_integer()
        }

  @doc """
  Execute a function with rate limiting.

  If rate limiting is disabled or not properly configured, the function
  is executed directly without queueing.

  ## Parameters

    - `request_fn` - A zero-arity function to execute
    - `opts` - Optional keyword list to override configuration

  ## Options

    - `:enabled` - Enable/disable rate limiting
    - `:repo` - Ecto repo for persistence
    - `:key` - Rate limit bucket key
    - `:request_count` - Max requests per window
    - `:time_window` - Window size in seconds
    - `:safety_margin` - Stay under limit by this percentage
    - `:max_retries` - Max retries for failed requests

  ## Returns

    The result of `request_fn.()`

  ## Examples

      RateLimiter.execute(fn -> make_api_call() end)

      RateLimiter.execute(
        fn -> make_api_call() end,
        key: "zoho:bulk",
        request_count: 10,
        time_window: 60
      )
  """
  @spec execute((-> result), keyword()) :: result when result: any()
  def execute(request_fn, opts \\ []) do
    config = build_config(opts)

    cond do
      not config.enabled ->
        request_fn.()

      is_nil(config.repo) ->
        # Rate limiter not properly configured, execute directly
        request_fn.()

      not rate_limiter_available?() ->
        # RateLimiter dependency not available, execute directly
        request_fn.()

      true ->
        execute_with_rate_limiter(request_fn, config)
    end
  end

  @doc """
  Check if rate limiting is available and properly configured.

  ## Examples

      if RateLimiter.available?() do
        # Rate limiting will be used
      end
  """
  @spec available?() :: boolean()
  def available? do
    config = build_config([])
    config.enabled and not is_nil(config.repo) and rate_limiter_available?()
  end

  @doc """
  Get the current configuration with any overrides applied.

  ## Examples

      config = RateLimiter.get_config(key: "custom")
      # => %{enabled: true, key: "custom", ...}
  """
  @spec get_config(keyword()) :: config()
  def get_config(opts \\ []) do
    build_config(opts)
  end

  # Private functions

  defp build_config(opts) do
    global_opts = Application.get_env(:zoho_api, :rate_limiter, [])
    merged_opts = Keyword.merge(Enum.to_list(global_opts), opts)

    Enum.reduce(merged_opts, @default_config, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp rate_limiter_available? do
    Code.ensure_loaded?(RateLimiter)
  end

  defp execute_with_rate_limiter(request_fn, config) do
    # The rate_limiter library expects {module, function, args} tuple
    # We wrap our anonymous function for compatibility
    rate_limiter_config =
      RateLimiter.Config.new(
        config.key,
        config.request_count,
        config.time_window,
        safety_margin: config.safety_margin,
        max_retries: config.max_retries
      )

    # Enqueue and wait for execution
    # Note: This is a blocking call that waits for the rate limiter to execute
    case RateLimiter.enqueue(
           config.repo,
           config.key,
           {__MODULE__, :execute_wrapper, [request_fn]},
           rate_limiter_config
         ) do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:rate_limiter_error, reason}}
    end
  end

  @doc false
  # Wrapper function for rate_limiter MFA format
  def execute_wrapper(request_fn) do
    request_fn.()
  end
end
