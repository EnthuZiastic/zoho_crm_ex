defmodule ZohoAPI.Cliq do
  @moduledoc """
  High-level Zoho Cliq client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`.

  ## Examples

      {:ok, result} = ZohoAPI.Cliq.create_message("Hello team!", "general")
  """

  alias ZohoAPI.Request
  alias ZohoAPI.TokenCache
  alias ZohoAPI.Validation

  @cliq_version "v2"

  # Note: This module builds a Request directly rather than going through
  # InputRequest. The Cliq API has no corresponding low-level module in
  # lib/zoho_api/modules/, so there is no InputRequest-based adapter to
  # delegate to. Retry and rate-limiting middleware that operate at the
  # Request level (not InputRequest) still apply.

  @spec create_message(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def create_message(message, channel_name) do
    with :ok <- Validation.validate_id(channel_name),
         {:ok, token} <- TokenCache.get_or_refresh(:cliq) do
      Request.new("cliq")
      |> Request.set_access_token(token)
      |> Request.with_version(@cliq_version)
      |> Request.with_method(:post)
      |> Request.with_path("channelsbyname/#{channel_name}/message")
      |> Request.with_body(%{text: message})
      |> Request.send()
    end
  end
end
