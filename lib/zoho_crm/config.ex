defmodule ZohoCrm.Config do
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

      config :zoho_crm, :crm,
        client_id: "crm_client_id",
        client_secret: "crm_client_secret"

      config :zoho_crm, :desk,
        client_id: "desk_client_id",
        client_secret: "desk_client_secret",
        org_id: "desk_org_id"

      config :zoho_crm, :workdrive,
        client_id: "workdrive_client_id",
        client_secret: "workdrive_client_secret"

  ## Legacy Configuration

  For backward compatibility, the legacy `:zoho` key is still supported
  and maps to the `:crm` service:

      config :zoho_crm, :zoho,
        client_id: "client_id",
        client_secret: "client_secret"

  ## Environment Variables

  Values can be environment variables:

      config :zoho_crm, :crm,
        client_id: {:system, "ZOHO_CRM_CLIENT_ID"},
        client_secret: {:system, "ZOHO_CRM_CLIENT_SECRET"}
  """

  defstruct [
    :client_id,
    :client_secret,
    :org_id
  ]

  @type service :: :crm | :desk | :workdrive | :recruit | :bookings | :projects

  @type t() :: %__MODULE__{
          client_id: String.t(),
          client_secret: String.t(),
          org_id: String.t() | nil
        }

  @valid_services [:crm, :desk, :workdrive, :recruit, :bookings, :projects]

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
    cfg = Enum.map(config, fn {k, v} -> {k, get_value(v)} end)
    struct!(__MODULE__, cfg)
  end

  def get_config(_service) do
    raise ArgumentError,
      message:
        "Invalid service. Must be one of: :crm, :desk, :workdrive, :recruit, :bookings, :projects"
  end

  defp get_service_config(service) do
    case Application.get_env(:zoho_crm, service) do
      nil -> get_fallback_config(service)
      config -> config
    end
  end

  defp get_fallback_config(:crm) do
    case Application.get_env(:zoho_crm, :zoho) do
      nil -> raise_missing_config(:crm)
      config -> config
    end
  end

  defp get_fallback_config(service), do: raise_missing_config(service)

  defp raise_missing_config(service) do
    raise ArgumentError,
      message:
        "Configuration for Zoho #{service} is not defined. " <>
          "Add config :zoho_crm, :#{service}, client_id: ..., client_secret: ..."
  end

  defp get_value({:system, system_var}), do: System.get_env(system_var)
  defp get_value(value), do: value
end
