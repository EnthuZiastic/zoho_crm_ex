defmodule ZohoAPI.Modules.CRM.CompositeTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.Composite

  setup :verify_on_exit!

  describe "execute/1" do
    test "executes composite requests" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
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

    test "passes parallel_execution parameter correctly in request body" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
        assert url =~ "crm/v8/__composite_requests"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        body_map = Jason.decode!(body)
        # Verify parallel_execution is passed through to the request body
        assert body_map["parallel_execution"] == false
        assert length(body_map["__composite_requests"]) == 2

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "__composite_responses" => [
                 %{"reference_id" => "1", "status_code" => 200},
                 %{"reference_id" => "2", "status_code" => 200}
               ]
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "parallel_execution" => false,
          "__composite_requests" => [
            %{
              "method" => "GET",
              "reference_id" => "1",
              "url" => "/crm/v8/Contacts/search",
              "params" => %{"criteria" => "(Email:equals:test@example.com)"}
            },
            %{
              "method" => "PUT",
              "reference_id" => "2",
              "url" => "/crm/v8/Contacts/@{1:$.data[0].id}",
              "body" => %{"data" => [%{"Phone" => "555-1234"}]}
            }
          ]
        })

      {:ok, result} = Composite.execute(input)

      assert length(result["__composite_responses"]) == 2
    end
  end

  describe "execute/1 validation" do
    test "returns error when more than 5 requests are provided" do
      requests =
        for i <- 1..6 do
          %{"method" => "GET", "reference_id" => "ref_#{i}", "url" => "/crm/v8/Leads"}
        end

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"__composite_requests" => requests})

      assert {:error, message} = Composite.execute(input)
      assert message =~ "maximum of 5 requests"
      assert message =~ "got 6"
    end

    test "returns error when no requests are provided" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"__composite_requests" => []})

      assert {:error, message} = Composite.execute(input)
      assert message =~ "At least one composite request is required"
    end

    test "returns error when body doesn't contain __composite_requests" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"invalid" => "body"})

      assert {:error, message} = Composite.execute(input)
      assert message =~ "must contain __composite_requests array"
    end

    test "returns error when request is missing 'method' field" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"reference_id" => "ref_1", "url" => "/crm/v8/Leads"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Request 1: missing required field 'method'"
    end

    test "returns error when request is missing 'reference_id' field" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "GET", "url" => "/crm/v8/Leads"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Request 1: missing required field 'reference_id'"
    end

    test "returns error when request is missing 'url' field" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "GET", "reference_id" => "ref_1"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Request 1: missing required field 'url'"
    end

    test "returns error for invalid HTTP method" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "PATCH", "reference_id" => "ref_1", "url" => "/crm/v8/Leads"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Request 1: invalid method 'PATCH'"
      assert message =~ "Must be one of: GET, POST, PUT, DELETE"
    end

    test "returns error for duplicate reference_ids" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "GET", "reference_id" => "same_ref", "url" => "/crm/v8/Leads"},
            %{"method" => "GET", "reference_id" => "same_ref", "url" => "/crm/v8/Contacts"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Duplicate reference_id found"
    end

    test "returns error for empty reference_id" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "GET", "reference_id" => "", "url" => "/crm/v8/Leads"}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "reference_id must be a non-empty string"
    end

    test "returns error for empty url" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "GET", "reference_id" => "ref_1", "url" => ""}
          ]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "url must be a non-empty string"
    end

    test "returns error when request is not a map" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => ["not a map"]
        })

      assert {:error, message} = Composite.execute(input)
      assert message =~ "Request 1: must be a map"
    end

    test "accepts lowercase HTTP methods" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"__composite_responses" => []})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "__composite_requests" => [
            %{"method" => "get", "reference_id" => "ref_1", "url" => "/crm/v8/Leads"}
          ]
        })

      assert {:ok, _} = Composite.execute(input)
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
