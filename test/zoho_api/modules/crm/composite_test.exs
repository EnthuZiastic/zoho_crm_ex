defmodule ZohoAPI.Modules.CRM.CompositeTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.Composite

  setup :verify_on_exit!

  describe "execute/1" do
    test "executes composite requests" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers ->
        assert url =~ "crm/v8/__composite_requests"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        body_map = Jason.decode!(body)
        assert length(body_map["__composite_requests"]) == 2

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "__composite_responses" => [
                 %{"reference_id" => "get_leads", "status_code" => 200},
                 %{"reference_id" => "create_contact", "status_code" => 201}
               ]
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{
              "method" => "GET",
              "reference_id" => "get_leads",
              "url" => "/crm/v8/Leads"
            },
            %{
              "method" => "POST",
              "reference_id" => "create_contact",
              "url" => "/crm/v8/Contacts",
              "body" => %{"data" => [%{"Last_Name" => "Test"}]}
            }
          ]
        })

      {:ok, result} = Composite.execute(input)

      assert length(result["__composite_responses"]) == 2
    end
  end

  describe "build_request/4" do
    test "builds GET request" do
      request = Composite.build_request(:get, "ref_1", "/crm/v8/Leads")

      assert request["method"] == "GET"
      assert request["reference_id"] == "ref_1"
      assert request["url"] == "/crm/v8/Leads"
      refute Map.has_key?(request, "body")
    end

    test "builds POST request with body" do
      body = %{"data" => [%{"Last_Name" => "Test"}]}
      request = Composite.build_request(:post, "ref_2", "/crm/v8/Leads", body: body)

      assert request["method"] == "POST"
      assert request["reference_id"] == "ref_2"
      assert request["body"] == body
    end
  end
end
