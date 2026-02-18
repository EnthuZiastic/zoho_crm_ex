defmodule ZohoAPI.TokenCache do
  @moduledoc """
  Thread-safe token caching and refresh coordination.

  This GenServer ensures that when multiple concurrent requests receive 401 errors,
  only one token refresh is performed. Other requests wait for the refresh to complete
  and receive the new token.

  ## Why This Matters

  Without coordination:
  - Multiple concurrent 401s trigger simultaneous refresh requests
  - Wastes API quota on the OAuth endpoint
  - May trigger rate limits
  - Some OAuth implementations invalidate refresh tokens after use

  ## Usage

  Start the TokenCache in your application supervision tree:

      children = [
        ZohoAPI.TokenCache,
        # ... other children
      ]

  Then use `refresh_token/4` instead of directly calling Token.refresh_access_token:

      case ZohoAPI.TokenCache.refresh_token(service, refresh_token, region, opts) do
        {:ok, access_token} -> # Use the token
        {:error, reason} -> # Handle error
      end

  ## Configuration

  Configure the cache TTL in your config:

      config :zoho_api, :token_cache,
        ttl_seconds: 3500  # Default: slightly less than Zoho's 1-hour expiry

  ## Manual Token Management

  If you manage tokens externally, you can manually update the cache:

      # Set a known valid token
      ZohoAPI.TokenCache.put_token(:crm, "access_token_value")

      # Get cached token without refresh
      ZohoAPI.TokenCache.get_token(:crm)

      # Invalidate cached token
      ZohoAPI.TokenCache.invalidate(:crm)
  """

  use GenServer

  require Logger

  alias ZohoAPI.Config
  alias ZohoAPI.Modules.Token

  @default_ttl_seconds 3500
  @default_refresh_timeout_ms 60_000

  # Client API

  @doc """
  Starts the TokenCache GenServer.

  Usually started as part of your application's supervision tree.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns a valid cached token, refreshing it if none is cached.

  Reads OAuth credentials (refresh_token, client_id, client_secret, region)
  directly from `ZohoAPI.Config` for the given service, so callers only need
  to pass the service atom.

  If another process is already refreshing the same service token, this call
  waits for that refresh to complete rather than issuing a duplicate request.

  The GenServer name is resolved via `config :zoho_api, :token_cache, name: ...`,
  defaulting to `ZohoAPI.TokenCache`. This allows enthu-backend to register
  the cache under Horde for cluster-wide sharing without any changes to call sites.

  ## Parameters

    - `service` - The Zoho service (`:crm`, `:project`, `:meeting`, etc.)

  ## Returns

    - `{:ok, access_token}` on success
    - `{:error, reason}` on failure

  ## Examples

      {:ok, token} = ZohoAPI.TokenCache.get_or_refresh(:crm)
  """
  @spec get_or_refresh(atom()) :: {:ok, String.t()} | {:error, any()}
  def get_or_refresh(service) do
    case get_token(service) do
      nil ->
        cfg = Config.get_config(service)
        region = cfg.region || :in
        do_refresh(service, cfg.refresh_token, region)

      token ->
        {:ok, token}
    end
  end

  @doc """
  Refreshes the access token with coordination to prevent duplicate refreshes.

  If another process is already refreshing the token for the same service,
  this call will wait for that refresh to complete and return the same result.

  ## Parameters

    - `service` - The Zoho service (`:crm`, `:desk`, `:recruit`, etc.)
    - `refresh_token` - The OAuth refresh token
    - `region` - The Zoho region (`:in`, `:com`, `:eu`, etc.)
    - `opts` - Optional keyword list with options passed to `Token.refresh_access_token/2`

  ## Returns

    - `{:ok, access_token}` on success
    - `{:error, reason}` on failure
  """
  @spec refresh_token(atom(), String.t(), atom(), keyword()) ::
          {:ok, String.t()} | {:error, any()}
  def refresh_token(service, refresh_token, region, opts \\ []) do
    do_refresh(service, refresh_token, region, opts)
  end

  defp do_refresh(service, refresh_token, region, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, get_refresh_timeout())
    token_opts = Keyword.delete(opts, :timeout)
    GenServer.call(cache_name(), {:refresh, service, refresh_token, region, token_opts}, timeout)
  end

  defp cache_name do
    Application.get_env(:zoho_api, :token_cache, [])
    |> Keyword.get(:name, __MODULE__)
  end

  defp get_refresh_timeout do
    Application.get_env(:zoho_api, :token_cache, [])
    |> Keyword.get(:refresh_timeout_ms, @default_refresh_timeout_ms)
  end

  @doc """
  Gets a cached token without triggering a refresh.

  Returns `nil` if no token is cached or if the cached token has expired.
  """
  @spec get_token(atom()) :: String.t() | nil
  def get_token(service) do
    GenServer.call(cache_name(), {:get, service})
  end

  @doc """
  Manually sets a token in the cache.

  Useful when you obtain tokens through external means (e.g., initial OAuth flow).
  """
  @spec put_token(atom(), String.t()) :: :ok
  def put_token(service, access_token) do
    GenServer.cast(cache_name(), {:put, service, access_token})
  end

  @doc """
  Invalidates the cached token for a service.

  Call this when you know a token is invalid (e.g., after receiving a 401).
  """
  @spec invalidate(atom()) :: :ok
  def invalidate(service) do
    GenServer.cast(cache_name(), {:invalidate, service})
  end

  @doc """
  Checks if the TokenCache process is running.
  """
  @spec available?() :: boolean()
  def available? do
    case Process.whereis(__MODULE__) do
      nil -> false
      _pid -> true
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      tokens: %{},
      refreshing: %{},
      ttl_seconds: get_ttl_config()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:refresh, service, refresh_token, region, opts}, from, state) do
    case Map.get(state.refreshing, service) do
      nil ->
        # No refresh in progress, start one
        state = start_refresh(state, service, refresh_token, region, opts, from)
        {:noreply, state}

      waiters when is_list(waiters) ->
        # Refresh already in progress, add to waiters
        new_waiters = [from | waiters]
        state = put_in(state.refreshing[service], new_waiters)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:get, service}, _from, state) do
    token = get_valid_token(state, service)
    {:reply, token, state}
  end

  @impl true
  def handle_cast({:put, service, access_token}, state) do
    state = cache_token(state, service, access_token)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalidate, service}, state) do
    state = %{state | tokens: Map.delete(state.tokens, service)}
    {:noreply, state}
  end

  @impl true
  def handle_info({:refresh_complete, service, result}, state) do
    # Get all waiters and reply to them
    waiters = Map.get(state.refreshing, service, [])

    # Update state based on result
    state =
      case result do
        {:ok, access_token} ->
          cache_token(state, service, access_token)

        {:error, _reason} ->
          state
      end

    # Reply to all waiters
    Enum.each(waiters, fn waiter ->
      GenServer.reply(waiter, result)
    end)

    # Clear the refreshing state
    state = %{state | refreshing: Map.delete(state.refreshing, service)}

    {:noreply, state}
  end

  # Private Functions

  defp start_refresh(state, service, refresh_token, region, opts, from) do
    # Mark as refreshing with the first waiter
    state = put_in(state.refreshing[service], [from])

    # Spawn the refresh task
    parent = self()

    Task.start(fn ->
      refresh_opts = opts |> Keyword.put(:region, region) |> Keyword.put(:service, service)

      result =
        case Token.refresh_access_token(refresh_token, refresh_opts) do
          {:ok, %{"access_token" => token}} ->
            {:ok, token}

          {:ok, response} ->
            Logger.warning("Unexpected token refresh response: #{inspect(response)}")
            {:error, {:unexpected_response, response}}

          {:error, reason} ->
            {:error, reason}
        end

      send(parent, {:refresh_complete, service, result})
    end)

    state
  end

  defp cache_token(state, service, access_token) do
    entry = %{
      token: access_token,
      expires_at: System.monotonic_time(:second) + state.ttl_seconds
    }

    %{state | tokens: Map.put(state.tokens, service, entry)}
  end

  defp get_valid_token(state, service) do
    case Map.get(state.tokens, service) do
      nil ->
        nil

      %{token: token, expires_at: expires_at} ->
        if System.monotonic_time(:second) < expires_at do
          token
        else
          nil
        end
    end
  end

  defp get_ttl_config do
    Application.get_env(:zoho_api, :token_cache, [])
    |> Keyword.get(:ttl_seconds, @default_ttl_seconds)
  end
end
