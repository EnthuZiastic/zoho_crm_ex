defmodule ZohoAPI.Config do
  @moduledoc """
  Configuration for Zoho API services.

  Supports multiple Zoho services with separate OAuth credentials:
  - :crm - Zoho CRM
  - :desk - Zoho Desk
  - :workdrive - Zoho WorkDrive
  - :recruit - Zoho Recruit
  - :bookings - Zoho Bookings
  - :projects - Zoho Projects

  ## Configuration

  Each service can have its own configuration:

      config :zoho_api, :crm,
        client_id: "crm_client_id",
        client_secret: "crm_client_secret"

      config :zoho_api, :desk,
        client_id: "desk_client_id",
        client_secret: "desk_client_secret",
        org_id: "desk_org_id"

      config :zoho_api, :workdrive,
        client_id: "workdrive_client_id",
        client_secret: "workdrive_client_secret"

  ## Legacy Configuration

  For backward compatibility, the legacy `:zoho` key is still supported
  and maps to the `:crm` service:

      config :zoho_api, :zoho,
        client_id: "client_id",
        client_secret: "client_secret"

  ## Environment Variables

  Values can reference environment variables using the `{:system, "VAR_NAME"}` tuple:

      config :zoho_api, :crm,
        client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
        client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}

  ### When Environment Variables Are Resolved

  **Important:** Environment variables are resolved at **runtime** when `get_config/1`
  is called, NOT at compile time. This allows you to:

  - Use the same compiled release in different environments (dev, staging, prod)
  - Change credentials without recompiling
  - Use container orchestration secrets that are injected at runtime

  Example flow:
  1. At compile time: `{:system, "ZOHO_CLIENT_ID"}` is stored as-is
  2. At runtime: When your code calls `Config.get_config(:crm)`, the library
     calls `System.get_env("ZOHO_CLIENT_ID")` to get the actual value

  ### Error Handling

  If an environment variable is not set or is empty when accessed, an
  `ArgumentError` is raised with a helpful message. Ensure your environment
  variables are set before making API calls.

  ## Timeout Configuration

  You can configure the default HTTP timeout (used for both connection and receive):

      config :zoho_api, :http_timeout, 60_000  # 60 seconds

  The default is 30 seconds (30_000 ms). This can be overridden per-request
  using `Request.with_timeout/2` and `Request.with_recv_timeout/2`.
  """

  defstruct [
    :client_id,
    :client_secret,
    :org_id,
    :refresh_token,
    :region
  ]

  @type service ::
          :crm
          | :desk
          | :workdrive
          | :recruit
          | :bookings
          | :projects
          | :meeting
          | :drive
          | :cliq

  @type t() :: %__MODULE__{
          client_id: String.t(),
          client_secret: String.t(),
          org_id: String.t() | nil,
          refresh_token: String.t() | nil,
          region: atom() | nil
        }

  @valid_services [
    :crm,
    :desk,
    :workdrive,
    :recruit,
    :bookings,
    :projects,
    :meeting,
    :drive,
    :cliq
  ]

  @struct_fields [:client_id, :client_secret, :org_id, :refresh_token, :region]

  @doc """
  Returns configuration for the specified Zoho service.

  ## Parameters

    - `service` - The Zoho service (default: :crm)

  ## Returns

    - `%Config{}` struct with client credentials

  ## Examples

      iex> Config.get_config(:crm)
      %Config{client_id: "...", client_secret: "..."}

      iex> Config.get_config(:desk)
      %Config{client_id: "...", client_secret: "...", org_id: "..."}
  """
  @spec get_config(service()) :: t()
  def get_config(service \\ :crm)

  def get_config(service) when service in @valid_services do
    config = get_service_config(service)

    cfg =
      config
      |> Enum.filter(fn {k, _v} -> k in @struct_fields end)
      |> Enum.map(fn {k, v} -> {k, get_value(v)} end)

    struct!(__MODULE__, cfg)
  end

  def get_config(_service) do
    raise ArgumentError,
      message:
        "Invalid service. Must be one of: " <>
          Enum.map_join(@valid_services, ", ", &inspect/1)
  end

  defp get_service_config(service) do
    case Application.get_env(:zoho_api, service) do
      nil -> get_fallback_config(service)
      config -> config
    end
  end

  defp get_fallback_config(:crm) do
    case Application.get_env(:zoho_api, :zoho) do
      nil -> raise_missing_config(:crm)
      config -> config
    end
  end

  defp get_fallback_config(service), do: raise_missing_config(service)

  defp raise_missing_config(service) do
    raise ArgumentError,
      message:
        "Configuration for Zoho #{service} is not defined. " <>
          "Add config :zoho_api, :#{service}, client_id: ..., client_secret: ..."
  end

  defp get_value({:system, system_var}) do
    case System.get_env(system_var) do
      nil ->
        raise ArgumentError,
          message:
            "Environment variable '#{system_var}' is not set. " <>
              "Please set this environment variable for your Zoho API configuration."

      "" ->
        raise ArgumentError,
          message:
            "Environment variable '#{system_var}' is set but empty. " <>
              "Please provide a valid value for your Zoho API configuration."

      value ->
        value
    end
  end

  defp get_value(nil), do: nil
  defp get_value(value), do: value
end
