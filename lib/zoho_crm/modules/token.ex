defmodule ZohoCrm.Modules.Token do
  @moduledoc """
  This modules handle access token generation
  """
  alias ZohoCrm.Request
  alias ZohoCrm.Config

  def refresh_access_token(refresh_token) when is_binary(refresh_token) do
    cfg = Config.get_config()

    params = %{
      client_id: cfg.client_id,
      client_secret: cfg.client_secret,
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    }

    Request.new("oauth")
    |> Request.set_base_url("https://accounts.zoho.in")
    |> Request.with_version("v2")
    |> Request.with_path("token")
    |> Request.with_method(:post)
    |> Request.with_params(params)
    |> Request.send()
  end
end
