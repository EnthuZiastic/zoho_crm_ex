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

    test "constructs CRM Bulk API URL" do
      url =
        Request.new("bulk")
        |> Request.with_path("read")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/bulk/v8/read"
    end

    test "constructs Recruit Bulk API URL" do
      url =
        Request.new("recruit_bulk")
        |> Request.with_version("v2")
        |> Request.with_path("read")
        |> Request.construct_url()

      assert url == "https://recruit.zoho.in/recruit/bulk/v2/read"
    end

    test "constructs Recruit Bulk API URL with region" do
      url =
        Request.new("recruit_bulk")
        |> Request.with_version("v2")
        |> Request.with_path("write")
        |> Request.with_region(:com)
        |> Request.construct_url()

      assert url == "https://recruit.zoho.com/recruit/bulk/v2/write"
    end

    test "constructs Composite API URL" do
      url =
        Request.new("composite")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/v8/__composite_requests"
    end

    test "constructs OAuth API URL" do
      url =
        Request.new("oauth")
        |> Request.set_base_url("https://accounts.zoho.in")
        |> Request.with_version("v2")
        |> Request.with_path("token")
        |> Request.construct_url()

      assert url == "https://accounts.zoho.in/oauth/v2/token"
    end

    test "constructs Recruit API URL" do
      url =
        Request.new("recruit")
        |> Request.with_version("v2")
        |> Request.with_path("Candidates")
        |> Request.construct_url()

      assert url == "https://recruit.zoho.in/recruit/v2/Candidates"
    end

    test "constructs Bookings API URL" do
      url =
        Request.new("bookings")
        |> Request.with_version("v1")
        |> Request.with_path("json/availableslots")
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/bookings/v1/json/availableslots"
    end

    test "constructs Projects/Portal API URL" do
      url =
        Request.new("portal")
        |> Request.with_path("/restapi/portal/123/projects")
        |> Request.construct_url()

      assert url == "https://projectsapi.zoho.in/restapi/portal/123/projects"
    end

    test "appends params with & when URL already has query string" do
      url =
        Request.new("crm")
        |> Request.with_path("Leads?existing=true")
        |> Request.with_params(%{page: 1})
        |> Request.construct_url()

      assert url == "https://www.zohoapis.in/crm/v8/Leads?existing=true&page=1"
    end
  end

  describe "with_timeout/2" do
    test "sets custom timeout" do
      request =
        Request.new()
        |> Request.with_timeout(60_000)

      assert request.timeout == 60_000
    end

    test "timeout is used in request" do
      request =
        Request.new()
        |> Request.with_timeout(120_000)

      assert request.timeout == 120_000
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

  describe "with_region/2" do
    test "sets region and affects URL construction" do
      url =
        Request.new("crm")
        |> Request.with_path("Leads")
        |> Request.with_region(:com)
        |> Request.construct_url()

      assert url == "https://www.zohoapis.com/crm/v8/Leads"
    end

    test "sets EU region for Desk API" do
      url =
        Request.new("desk")
        |> Request.with_version("v1")
        |> Request.with_path("tickets")
        |> Request.with_region(:eu)
        |> Request.construct_url()

      assert url == "https://desk.zoho.eu/api/v1/tickets"
    end

    test "sets AU region for Recruit API" do
      url =
        Request.new("recruit")
        |> Request.with_version("v2")
        |> Request.with_path("Candidates")
        |> Request.with_region(:au)
        |> Request.construct_url()

      assert url == "https://recruit.zoho.com.au/recruit/v2/Candidates"
    end

    test "sets JP region for WorkDrive API" do
      url =
        Request.new("workdrive")
        |> Request.with_version("v1")
        |> Request.with_path("files")
        |> Request.with_region(:jp)
        |> Request.construct_url()

      assert url == "https://www.zohoapis.jp/workdrive/api/v1/files"
    end
  end

  describe "send/1 error handling" do
    import Mox

    setup :verify_on_exit!

    test "handles HTTP client errors" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end)

      result =
        Request.new()
        |> Request.with_path("Leads")
        |> Request.with_method(:get)
        |> Request.set_access_token("token")
        |> Request.send()

      assert {:error, :timeout} = result
    end

    test "handles non-2xx status codes as errors" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 401,
           body: Jason.encode!(%{"code" => "INVALID_TOKEN", "message" => "Token expired"})
         }}
      end)

      result =
        Request.new()
        |> Request.with_path("Leads")
        |> Request.with_method(:get)
        |> Request.set_access_token("token")
        |> Request.send()

      assert {:error, %{"code" => "INVALID_TOKEN"}} = result
    end
  end
end
