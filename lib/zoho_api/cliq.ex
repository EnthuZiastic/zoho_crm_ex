defmodule ZohoAPI.Cliq do
  @moduledoc """
  High-level Zoho Cliq client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`.

  ## Examples

      {:ok, result} = ZohoAPI.Cliq.create_message("Hello team!", "general")
  """

  alias ZohoAPI.Request
  alias ZohoAPI.TokenCache

  @cliq_version "v2"

  @spec create_message(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def create_message(message, channel_name) do
    with {:ok, token} <- TokenCache.get_or_refresh(:cliq) do
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
