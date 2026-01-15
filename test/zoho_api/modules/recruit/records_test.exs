defmodule ZohoAPI.Modules.Recruit.RecordsTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Recruit.Records

  setup :verify_on_exit!

  describe "get_records/1" do
    test "gets records from a Recruit module" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "data" => [
                 %{"id" => "123", "Last_Name" => "Smith"},
                 %{"id" => "456", "Last_Name" => "Jones"}
               ]
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:ok, result} = Records.get_records(input)

      assert length(result["data"]) == 2
    end

    test "respects region setting" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.com/recruit/v8/Candidates"

        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"data" => []})}}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_region(:com)

      {:ok, _result} = Records.get_records(input)
    end
  end

  describe "get_record/2" do
    test "gets a specific record by ID" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates/record_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "record_123", "Last_Name" => "Smith"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:ok, result} = Records.get_record(input, "record_123")

      assert hd(result["data"])["id"] == "record_123"
    end

    test "validates record_id" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:error, error} = Records.get_record(input, "../../../etc/passwd")

      assert error =~ "path traversal not allowed"
    end
  end

  describe "insert_records/1" do
    test "inserts new records" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"

        body_map = Jason.decode!(body)
        assert body_map["data"] == [%{"Last_Name" => "Smith", "Email" => "smith@example.com"}]

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
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_body([%{"Last_Name" => "Smith", "Email" => "smith@example.com"}])

      {:ok, result} = Records.insert_records(input)

      assert hd(result["data"])["code"] == "SUCCESS"
    end
  end

  describe "update_records/1" do
    test "updates existing records" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :put, url, body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"

        body_map = Jason.decode!(body)
        assert hd(body_map["data"])["id"] == "record_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"code" => "SUCCESS"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_body([%{"id" => "record_123", "Last_Name" => "Updated"}])

      {:ok, result} = Records.update_records(input)

      assert hd(result["data"])["code"] == "SUCCESS"
    end
  end

  describe "upsert_records/2" do
    test "upserts records with duplicate check fields" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates/upsert"

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
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_body([%{"Email" => "test@example.com"}])

      {:ok, result} = Records.upsert_records(input, duplicate_check_fields: ["Email"])

      assert hd(result["data"])["code"] == "SUCCESS"
    end
  end

  describe "search_records/1" do
    test "searches records with criteria" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates/search"
        assert url =~ "criteria"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "123"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_query_params(%{"criteria" => "(Last_Name:equals:Smith)"})

      {:ok, result} = Records.search_records(input)

      assert length(result["data"]) == 1
    end
  end

  describe "delete_records/1" do
    test "deletes records by IDs" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :delete, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"
        # IDs are URL-encoded (comma becomes %2C)
        assert url =~ "ids=123" or url =~ "ids=123%2C456"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "data" => [
                 %{"code" => "SUCCESS", "details" => %{"id" => "123"}},
                 %{"code" => "SUCCESS", "details" => %{"id" => "456"}}
               ]
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_query_params(%{"ids" => "123,456"})

      {:ok, result} = Records.delete_records(input)

      assert length(result["data"]) == 2
    end
  end

  describe "get_associated_records/2" do
    test "gets associated records for a record" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates/record_123/associate"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "assoc_1"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:ok, result} = Records.get_associated_records(input, "record_123")

      assert length(result["data"]) == 1
    end

    test "validates record_id" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:error, error} = Records.get_associated_records(input, "invalid/id")

      assert error =~ "path separators not allowed"
    end
  end

  describe "deprecated functions" do
    test "get_recruit_records/1 delegates to get_records/1" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"

        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"data" => []})}}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")

      {:ok, _result} = Records.get_recruit_records(input)
    end

    test "insert_recruit_records/1 delegates to insert_records/1" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/Candidates"

        {:ok, %HTTPoison.Response{status_code: 201, body: Jason.encode!(%{"data" => []})}}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_module_api_name("Candidates")
        |> InputRequest.with_body([%{"Last_Name" => "Test"}])

      {:ok, _result} = Records.insert_recruit_records(input)
    end
  end
end
