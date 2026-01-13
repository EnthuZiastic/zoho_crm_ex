defmodule ZohoCrm.ConfigTest do
  use ExUnit.Case, async: true

  alias ZohoCrm.Config

  describe "get_config/1" do
    test "returns config for :crm service" do
      Application.put_env(:zoho_crm, :crm,
        client_id: "crm_client_id",
        client_secret: "crm_client_secret"
      )

      config = Config.get_config(:crm)

      assert config.client_id == "crm_client_id"
      assert config.client_secret == "crm_client_secret"

      Application.delete_env(:zoho_crm, :crm)
    end

    test "returns config for :desk service with org_id" do
      Application.put_env(:zoho_crm, :desk,
        client_id: "desk_client_id",
        client_secret: "desk_client_secret",
        org_id: "desk_org_id"
      )

      config = Config.get_config(:desk)

      assert config.client_id == "desk_client_id"
      assert config.client_secret == "desk_client_secret"
      assert config.org_id == "desk_org_id"

      Application.delete_env(:zoho_crm, :desk)
    end

    test "falls back to legacy :zoho config for :crm" do
      Application.put_env(:zoho_crm, :zoho,
        client_id: "legacy_client_id",
        client_secret: "legacy_client_secret"
      )

      config = Config.get_config(:crm)

      assert config.client_id == "legacy_client_id"
      assert config.client_secret == "legacy_client_secret"

      Application.delete_env(:zoho_crm, :zoho)
    end

    test "raises error for invalid service" do
      assert_raise ArgumentError, fn ->
        Config.get_config(:invalid)
      end
    end

    test "raises error when config is missing" do
      Application.delete_env(:zoho_crm, :workdrive)

      assert_raise ArgumentError, fn ->
        Config.get_config(:workdrive)
      end
    end
  end
end
