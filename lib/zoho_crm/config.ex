defmodule ZohoCrm.Config do
  @moduledoc """
  Configuration for Zoho CRm
  """

  defstruct [
    :client_id,
    :client_secret
  ]

  @type t() :: %__MODULE__{
          client_id: String.t(),
          client_secret: String.t()
        }

  @doc """
  returns configuration for Zoho CRM

  ## Example


      iex> get_config()
      %Config{client_id: "zoho api client id", client_secret: "zoho api client secret}
  """
  @spec get_config() :: Config.t()
  def get_config do
    case Application.get_env(:zoho_crm, :zoho) do
      nil ->
        raise ArgumentError, message: "Environment variables for zoho crm is not defined"

      config ->
        cfg = Enum.map(config, fn {k, v} -> {k, get_value(v)} end)
        struct!(__MODULE__, cfg)
    end
  end

  defp get_value({:system, system_var}), do: System.get_env(system_var)
  defp get_value(value), do: value
end
