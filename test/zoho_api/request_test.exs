defmodule ZohoAPI.RequestTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.Request

  describe "new/1" do
    test "creates request with default crm api type" do
      request = Request.new()

      assert request.api_type == "crm"
      assert request.version == "v8"
      assert request.base_url == "https://www.zohoapis.in"
    end

    test "creates request with specified api type" do
      request = Request.new("desk")

      assert request.api_type == "desk"
    end
  end

  describe "construct_url/1" do
    test "constructs CRM API URL" do
      url =
        Request.new("crm")
        |> Request.with_path("Leads")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/v8/Leads"
    end

    test "constructs CRM API URL with params" do
      url =
        Request.new("crm")
        |> Request.with_path("Leads")
        |> Request.with_params(%{page: 1})
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/v8/Leads?page=1"
    end

    test "constructs Desk API URL" do
      url =
        Request.new("desk")
        |> Request.with_version("v1")
        |> Request.with_path("tickets")
        |> Request.construct_url()

      assert url == "https://desk.zoho.in/api/v1/tickets"
    end

    test "constructs WorkDrive API URL" do
      url =
        Request.new("workdrive")
        |> Request.with_version("v1")
        |> Request.with_path("files")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/workdrive/api/v1/files"
    end

    test "constructs Bulk API URL" do
      url =
        Request.new("bulk")
        |> Request.with_path("read")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/bulk/v8/read"
    end

    test "constructs Composite API URL" do
      url =
        Request.new("composite")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/v8/__composite_requests"
    end
  end

  describe "set_access_token/2" do
    test "sets authorization header" do
      request =
        Request.new()
        |> Request.set_access_token("test_token")

      assert request.headers["Authorization"] == "Zoho-oauthtoken test_token"
    end
  end

  describe "set_org_id/2" do
    test "sets orgId header" do
      request =
        Request.new()
        |> Request.set_org_id("org_123")

      assert request.headers["orgId"] == "org_123"
    end
  end
end
