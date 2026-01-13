defmodule ZohoAPI.InputRequestTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.InputRequest

  describe "new/4" do
    test "creates input request with access token" do
      input = InputRequest.new("test_token")

      assert input.access_token == "test_token"
      assert input.module_api_name == nil
      assert input.query_params == %{}
      assert input.body == %{}
      assert input.org_id == nil
    end

    test "creates input request with all parameters" do
      input = InputRequest.new("token", "Leads", %{page: 1}, %{data: "value"})

      assert input.access_token == "token"
      assert input.module_api_name == "Leads"
      assert input.query_params == %{page: 1}
      assert input.body == %{data: "value"}
    end
  end

  describe "with_module_api_name/2" do
    test "sets module api name" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_module_api_name("Contacts")

      assert input.module_api_name == "Contacts"
    end
  end

  describe "with_query_params/2" do
    test "sets query parameters" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_query_params(%{limit: 10, offset: 0})

      assert input.query_params == %{limit: 10, offset: 0}
    end
  end

  describe "with_body/2" do
    test "sets request body" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_body(%{"Email" => "test@example.com"})

      assert input.body == %{"Email" => "test@example.com"}
    end
  end

  describe "with_org_id/2" do
    test "sets organization id" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_org_id("org_123")

      assert input.org_id == "org_123"
    end
  end

  describe "with_refresh_token/2" do
    test "sets refresh token" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_refresh_token("refresh_token_123")

      assert input.refresh_token == "refresh_token_123"
    end
  end

  describe "with_on_token_refresh/2" do
    test "sets token refresh callback" do
      callback = fn _new_token -> :ok end

      input =
        InputRequest.new("token")
        |> InputRequest.with_on_token_refresh(callback)

      assert input.on_token_refresh == callback
    end
  end

  describe "with_retry_opts/2" do
    test "sets retry options" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_retry_opts(max_retries: 5, base_delay_ms: 500)

      assert input.retry_opts == [max_retries: 5, base_delay_ms: 500]
    end
  end

  describe "with_rate_limit_opts/2" do
    test "sets rate limit options" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_rate_limit_opts(enabled: false, key: "custom")

      assert input.rate_limit_opts == [enabled: false, key: "custom"]
    end
  end

  describe "with_region/2" do
    test "sets region" do
      input =
        InputRequest.new("token")
        |> InputRequest.with_region(:com)

      assert input.region == :com
    end

    test "defaults to :in region" do
      input = InputRequest.new("token")
      assert input.region == :in
    end
  end
end
