defmodule ZohoCrm.Modules.CRM.RecordsTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Modules.CRM.Records

  setup :verify_on_exit!

  describe "get_records/1" do
    test "fetches records from a module" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, headers ->
        assert url =~ "crm/v8/Leads"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "123"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")

      {:ok, result} = Records.get_records(input)

      assert result["data"] == [%{"id" => "123"}]
    end
  end

  describe "get_record/2" do
    test "fetches a specific record by ID" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "crm/v8/Leads/record_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "record_123"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")

      {:ok, result} = Records.get_record(input, "record_123")

      assert result["data"] == [%{"id" => "record_123"}]
    end
  end

  describe "insert_records/1" do
    test "inserts new records" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :post, url, body, _headers ->
        assert url =~ "crm/v8/Contacts"
        body_map = Jason.decode!(body)
        assert body_map["data"] == [%{"Last_Name" => "Smith"}]

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "data" => [%{"code" => "SUCCESS", "details" => %{"id" => "new_123"}}]
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Contacts")
        |> InputRequest.with_body([%{"Last_Name" => "Smith"}])

      {:ok, result} = Records.insert_records(input)

      assert result["data"] == [%{"code" => "SUCCESS", "details" => %{"id" => "new_123"}}]
    end
  end

  describe "upsert_records/2" do
    test "upserts records with duplicate check fields" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :post, url, body, _headers ->
        assert url =~ "crm/v8/Leads/upsert"
        body_map = Jason.decode!(body)
        assert body_map["duplicate_check_fields"] == ["Email"]

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"code" => "SUCCESS"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")
        |> InputRequest.with_body([%{"Email" => "test@example.com"}])

      {:ok, result} = Records.upsert_records(input, duplicate_check_fields: ["Email"])

      assert result["data"] == [%{"code" => "SUCCESS"}]
    end
  end

  describe "update_records/1" do
    test "updates existing records" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :put, url, _body, _headers ->
        assert url =~ "crm/v8/Leads"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"code" => "SUCCESS"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")
        |> InputRequest.with_body([%{"id" => "123", "Last_Name" => "Updated"}])

      {:ok, result} = Records.update_records(input)

      assert result["data"] == [%{"code" => "SUCCESS"}]
    end
  end

  describe "search_records/1" do
    test "searches records" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "crm/v8/Leads/search"
        assert url =~ "criteria"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "found_123"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")
        |> InputRequest.with_query_params(%{criteria: "(Email:equals:test@example.com)"})

      {:ok, result} = Records.search_records(input)

      assert result["data"] == [%{"id" => "found_123"}]
    end
  end

  describe "coql_query/1" do
    test "executes COQL query" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :post, url, body, _headers ->
        assert url =~ "crm/v8/coql"
        body_map = Jason.decode!(body)
        assert body_map["select_query"] =~ "from Leads"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"Last_Name" => "Test"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"select_query" => "select Last_Name from Leads"})

      {:ok, result} = Records.coql_query(input)

      assert result["data"] == [%{"Last_Name" => "Test"}]
    end
  end

  describe "delete_records/1" do
    test "deletes records" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :delete, url, _body, _headers ->
        assert url =~ "crm/v8/Leads"
        assert url =~ "ids=123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"code" => "SUCCESS"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Leads")
        |> InputRequest.with_query_params(%{ids: "123"})

      {:ok, result} = Records.delete_records(input)

      assert result["data"] == [%{"code" => "SUCCESS"}]
    end
  end
end
