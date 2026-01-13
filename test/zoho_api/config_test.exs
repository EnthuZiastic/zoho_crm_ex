defmodule ZohoAPI.ConfigTest do
  # Not async because tests modify global Application config
  use ExUnit.Case, async: false

  alias ZohoAPI.Config

  setup do
    # Save original configs
    original_crm = Application.get_env(:zoho_api, :crm)
    original_desk = Application.get_env(:zoho_api, :desk)
    original_zoho = Application.get_env(:zoho_api, :zoho)
    original_workdrive = Application.get_env(:zoho_api, :workdrive)

    on_exit(fn ->
      # Restore original configs
      if original_crm,
        do: Application.put_env(:zoho_api, :crm, original_crm),
        else: Application.delete_env(:zoho_api, :crm)

      if original_desk,
        do: Application.put_env(:zoho_api, :desk, original_desk),
        else: Application.delete_env(:zoho_api, :desk)

      if original_zoho,
        do: Application.put_env(:zoho_api, :zoho, original_zoho),
        else: Application.delete_env(:zoho_api, :zoho)

      if original_workdrive,
        do: Application.put_env(:zoho_api, :workdrive, original_workdrive),
        else: Application.delete_env(:zoho_api, :workdrive)
    end)

    :ok
  end

  describe "get_config/1" do
    test "returns config for :crm service" do
      Application.put_env(:zoho_api, :crm,
        client_id: "crm_client_id",
        client_secret: "crm_client_secret"
      )

      config = Config.get_config(:crm)

      assert config.client_id == "crm_client_id"
      assert config.client_secret == "crm_client_secret"
    end

    test "returns config for :desk service with org_id" do
      Application.put_env(:zoho_api, :desk,
        client_id: "desk_client_id",
        client_secret: "desk_client_secret",
        org_id: "desk_org_id"
      )

      config = Config.get_config(:desk)

      assert config.client_id == "desk_client_id"
      assert config.client_secret == "desk_client_secret"
      assert config.org_id == "desk_org_id"
    end

    test "falls back to legacy :zoho config for :crm" do
      # Delete :crm config to force fallback to :zoho
      Application.delete_env(:zoho_api, :crm)

      Application.put_env(:zoho_api, :zoho,
        client_id: "legacy_client_id",
        client_secret: "legacy_client_secret"
      )

      config = Config.get_config(:crm)

      assert config.client_id == "legacy_client_id"
      assert config.client_secret == "legacy_client_secret"
    end

    test "raises error for invalid service" do
      assert_raise ArgumentError, fn ->
        Config.get_config(:invalid)
      end
    end

    test "raises error when config is missing" do
      Application.delete_env(:zoho_api, :workdrive)

      assert_raise ArgumentError, fn ->
        Config.get_config(:workdrive)
      end
    end

    test "raises error when env var is not set" do
      Application.put_env(:zoho_api, :crm,
        client_id: {:system, "ZOHO_TEST_MISSING_ENV_VAR"},
        client_secret: "secret"
      )

      # Ensure the env var doesn't exist
      System.delete_env("ZOHO_TEST_MISSING_ENV_VAR")

      # Error message includes the variable name for easier debugging
      assert_raise ArgumentError,
                   ~r/Environment variable 'ZOHO_TEST_MISSING_ENV_VAR' is not set/,
                   fn ->
                     Config.get_config(:crm)
                   end
    end

    test "raises error when env var is empty" do
      Application.put_env(:zoho_api, :crm,
        client_id: {:system, "ZOHO_TEST_EMPTY_ENV_VAR"},
        client_secret: "secret"
      )

      System.put_env("ZOHO_TEST_EMPTY_ENV_VAR", "")

      # Error message includes the variable name for easier debugging
      assert_raise ArgumentError,
                   ~r/Environment variable 'ZOHO_TEST_EMPTY_ENV_VAR' is set but empty/,
                   fn ->
                     Config.get_config(:crm)
                   end

      System.delete_env("ZOHO_TEST_EMPTY_ENV_VAR")
    end
  end
end
