defmodule ZohoAPI.Modules.CRM.BulkWriteTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.BulkWrite

  setup :verify_on_exit!

  describe "upload_file/2" do
    test "uploads a CSV file" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers ->
        assert url =~ "crm/bulk/v8/write/file"
        assert url =~ "module=Leads"
        assert {"Content-Type", "text/csv"} in headers
        assert body == "Last_Name,Email\nSmith,smith@example.com"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "success",
               "details" => %{"file_id" => "file_123"}
             })
         }}
      end)

      csv_content = "Last_Name,Email\nSmith,smith@example.com"

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(csv_content)

      {:ok, result} = BulkWrite.upload_file(input, "Leads")

      assert result["details"]["file_id"] == "file_123"
    end
  end

  describe "create_job/1" do
    test "creates a bulk write job" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers ->
        assert url =~ "crm/bulk/v8/write"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        body_map = Jason.decode!(body)
        assert body_map["operation"] == "insert"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "status" => "ADDED",
               "details" => %{"id" => "job_456"}
             })
         }}
      end)

      job_config = %{
        "operation" => "insert",
        "resource" => [
          %{
            "type" => "data",
            "module" => %{"api_name" => "Leads"},
            "file_id" => "file_123",
            "field_mappings" => [
              %{"api_name" => "Last_Name", "index" => 0},
              %{"api_name" => "Email", "index" => 1}
            ]
          }
        ]
      }

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(job_config)

      {:ok, result} = BulkWrite.create_job(input)

      assert result["status"] == "ADDED"
      assert result["details"]["id"] == "job_456"
    end
  end

  describe "get_job_status/2" do
    test "gets bulk write job status" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "crm/bulk/v8/write/job_456"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "COMPLETED",
               "result" => %{
                 "added_count" => 100,
                 "skipped_count" => 2
               }
             })
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = BulkWrite.get_job_status(input, "job_456")

      assert result["status"] == "COMPLETED"
      assert result["result"]["added_count"] == 100
    end
  end
end
