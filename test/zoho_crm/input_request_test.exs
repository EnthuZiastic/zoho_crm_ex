defmodule ZohoCrm.InputRequestTest do
  use ExUnit.Case, async: true

  alias ZohoCrm.InputRequest

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
end
