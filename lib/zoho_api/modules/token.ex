defmodule ZohoAPI.Modules.Token do
  @moduledoc """
  Zoho OAuth Token Management.

  This module handles OAuth token operations for all Zoho services.
  It supports refreshing access tokens using refresh tokens.

  ## Multi-Service Support

  Each Zoho service (CRM, Desk, WorkDrive, etc.) can have its own
  OAuth credentials configured. Use the `service` option to specify
  which credentials to use.

  ## Region Support

  Zoho has multiple data centers. Use the appropriate region:
    - `:in` - India (default)
    - `:com` - United States
    - `:eu` - Europe
    - `:au` - Australia
    - `:jp` - Japan
    - `:uk` - United Kingdom
    - `:ca` - Canada
    - `:sa` - Saudi Arabia

  ## Examples

      # Refresh token for CRM (default)
      {:ok, %{"access_token" => token}} = Token.refresh_access_token("refresh_token")

      # Refresh token for Desk service
      {:ok, %{"access_token" => token}} = Token.refresh_access_token("refresh_token", service: :desk)

      # Refresh token for EU region
      {:ok, %{"access_token" => token}} = Token.refresh_access_token("refresh_token", region: :eu)
  """

  alias ZohoAPI.Config
  alias ZohoAPI.Regions
  alias ZohoAPI.Request

  @doc """
  Refreshes an access token using a refresh token.

  ## Parameters

    - `refresh_token` - The OAuth refresh token
    - `opts` - Options:
      - `:service` - The Zoho service (:crm, :desk, :workdrive, etc.). Default: :crm
      - `:region` - The Zoho region (:in, :com, :eu, etc.). Default: :in

  ## Returns

    - `{:ok, %{"access_token" => "...", "expires_in" => ...}}` on success
    - `{:error, reason}` on failure

  ## Examples

      Token.refresh_access_token("1000.abc123...")
      Token.refresh_access_token("1000.abc123...", service: :desk, region: :com)
  """
  @spec refresh_access_token(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def refresh_access_token(refresh_token, opts \\ [])

  def refresh_access_token(refresh_token, opts) when is_binary(refresh_token) do
    service = Keyword.get(opts, :service, :crm)
    region = Keyword.get(opts, :region, :in)
    cfg = Config.get_config(service)
    base_url = Regions.oauth_url(region)

    # OAuth credentials sent as form-encoded body for security (not in URL query params)
    body =
      URI.encode_query(%{
        client_id: cfg.client_id,
        client_secret: cfg.client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      })

    Request.new("oauth")
    |> Request.set_base_url(base_url)
    |> Request.with_version("v2")
    |> Request.with_path("token")
    |> Request.with_method(:post)
    |> Request.set_headers(%{"Content-Type" => "application/x-www-form-urlencoded"})
    |> Request.with_body(body)
    |> Request.send()
  end

  def refresh_access_token(_, _), do: {:error, "INVALID_REFRESH_TOKEN"}

  @doc """
  Refreshes an access token and validates it has the required scopes.

  This is the recommended way to refresh tokens as it fails fast with
  a clear error if the token lacks required API scopes.

  ## Parameters

    - `refresh_token` - The OAuth refresh token
    - `opts` - Options:
      - `:service` - The Zoho service (:crm, :desk, :workdrive, etc.). Default: :crm
      - `:region` - The Zoho region (:in, :com, :eu, etc.). Default: :in

  ## Returns

    - `{:ok, %{"access_token" => "...", "expires_in" => ...}}` on success
    - `{:error, {:missing_scopes, service, message}}` if token lacks required scopes
    - `{:error, reason}` on other failures

  ## Examples

      Token.refresh_and_validate("1000.abc123...", service: :crm)
      # Returns {:error, {:missing_scopes, :crm, "Token lacks CRM scopes..."}} if invalid
  """
  @spec refresh_and_validate(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def refresh_and_validate(refresh_token, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)
    region = Keyword.get(opts, :region, :in)

    case refresh_access_token(refresh_token, opts) do
      {:ok, token_data} ->
        case validate_token(token_data["access_token"], service: service, region: region) do
          :ok ->
            {:ok, token_data}

          {:error, {:missing_scopes, svc, _message}} ->
            # Scopes come from refresh token, so that's what needs to be regenerated
            {:error,
             {:invalid_refresh_token, svc, refresh_token, scope_error_message(svc, region)}}

          {:error, _} = error ->
            error
        end

      {:error, %{"error" => "invalid_code"}} ->
        {:error,
         {:invalid_refresh_token, service, refresh_token,
          "Refresh token is invalid or expired. Generate a new one."}}

      {:error, %{"error" => "invalid_client"}} ->
        {:error,
         {:invalid_client, "Client ID or Client Secret is invalid. Check your configuration."}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates that an access token has the required scopes for a service.

  Makes a lightweight API call to check if the token can access the service.
  Fails fast with a descriptive error if scopes are missing.

  ## Parameters

    - `access_token` - The OAuth access token to validate
    - `opts` - Options:
      - `:service` - The Zoho service to validate for (:crm, :desk). Default: :crm
      - `:region` - The Zoho region. Default: :in

  ## Returns

    - `:ok` if token has required scopes
    - `{:error, {:missing_scopes, service, message}}` if scopes are missing

  ## Examples

      Token.validate_token("1000.abc...", service: :crm)
      # => :ok

      Token.validate_token("1000.abc...", service: :crm)
      # => {:error, {:missing_scopes, :crm, "Token lacks CRM API scopes..."}}
  """
  @spec validate_token(String.t(), keyword()) :: :ok | {:error, any()}
  def validate_token(access_token, opts \\ []) do
    service = Keyword.get(opts, :service, :crm)
    region = Keyword.get(opts, :region, :in)

    case service do
      :crm -> validate_crm_token(access_token, region)
      :desk -> validate_desk_token(access_token, region)
      # For other services, skip validation (can be added later)
      _ -> :ok
    end
  end

  @doc """
  Returns the OAuth URL for a specific region.

  ## Parameters

    - `region` - The Zoho region atom

  ## Examples

      Token.oauth_url(:in)
      # => "https://accounts.zoho.in"

      Token.oauth_url(:eu)
      # => "https://accounts.zoho.eu"
  """
  @spec oauth_url(atom()) :: String.t()
  def oauth_url(region) when is_atom(region) do
    Regions.oauth_url(region)
  end

  # Validate CRM token by calling /org endpoint (returns clear OAUTH_SCOPE_MISMATCH if invalid)
  defp validate_crm_token(access_token, region) do
    result =
      Request.new("crm")
      |> Request.set_access_token(access_token)
      |> Request.with_region(region)
      |> Request.with_version("v2")
      |> Request.with_path("org")
      |> Request.with_method(:get)
      |> Request.send_raw()

    case result do
      {:ok, status, _body} when status in 200..299 ->
        :ok

      {:ok, _status, %{"code" => code}} when code in ["OAUTH_SCOPE_MISMATCH", "INVALID_TOKEN"] ->
        {:error, {:missing_scopes, :crm, scope_error_message(:crm, region)}}

      {:ok, _status, %{"code" => "INVALID_REQUEST"}} ->
        # Generic error often means scope issues too
        {:error, {:missing_scopes, :crm, scope_error_message(:crm, region)}}

      {:ok, _status, body} ->
        {:error, {:validation_failed, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate Desk token by calling /organizations endpoint
  defp validate_desk_token(access_token, region) do
    base_url = Regions.api_url(:desk, region)

    result =
      Request.new("desk")
      |> Request.set_access_token(access_token)
      |> Request.set_base_url(base_url)
      |> Request.with_version("v1")
      |> Request.with_path("organizations")
      |> Request.with_method(:get)
      |> Request.send_raw()

    case result do
      {:ok, status, _body} when status in 200..299 ->
        :ok

      {:ok, _status, %{"errorCode" => "SCOPE_MISMATCH"}} ->
        {:error, {:missing_scopes, :desk, scope_error_message(:desk, region)}}

      {:ok, _status, body} ->
        {:error, {:validation_failed, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp scope_error_message(:crm, region) do
    console_url =
      if region == :in, do: "https://api-console.zoho.in", else: "https://api-console.zoho.com"

    """
    Your OAuth token lacks CRM API scopes.

    To fix:
      1. Go to #{console_url}
      2. Select your OAuth client (or create a Self Client)
      3. Generate a new code with scopes:
         ZohoCRM.modules.ALL,ZohoCRM.settings.ALL,ZohoCRM.users.ALL
      4. Exchange the code for a new refresh token
      5. Update your configuration with the new refresh token
    """
  end

  defp scope_error_message(:desk, region) do
    console_url =
      if region == :in, do: "https://api-console.zoho.in", else: "https://api-console.zoho.com"

    """
    Your OAuth token lacks Desk API scopes.

    To fix:
      1. Go to #{console_url}
      2. Select your OAuth client (or create a Self Client)
      3. Generate a new code with scopes:
         Desk.tickets.ALL,Desk.contacts.ALL,Desk.settings.ALL
      4. Exchange the code for a new refresh token
      5. Update your configuration with the new refresh token
    """
  end
end
