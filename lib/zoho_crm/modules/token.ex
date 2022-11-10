defmodule ZohoCrm.Modules.Token do
  alias ZohoCrm.Request
  alias ZohoCrm.Config

  def refresh_access_token do
    cfg = Config.get_config()

    params = %{
      client_id: cfg.client_id,
      client_secret: cfg.client_secret,
      refresh_token: cfg.refresh_token,
      grant_type: "refresh_token"
    }

    Request.new()
    |> Request.set_base_url("https://accounts.zoho.in")
    |> Request.with_path("")
    |> Request.with_method(:post)
  end
end
