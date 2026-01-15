defmodule ZohoAPI.Modules.Bulk.WriteTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Bulk.Write

  setup :verify_on_exit!

  describe "upload_file/3 for CRM" do
    test "uploads a file for CRM bulk write (default service)" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
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

      {:ok, result} = Write.upload_file(input, "Leads")

      assert result["status"] == "success"
      assert result["details"]["file_id"] == "file_123"
    end
  end

  describe "upload_file/3 for Recruit" do
    test "uploads a file for Recruit bulk write" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/bulk/write/file"
        assert url =~ "module=Candidates"
        assert {"Content-Type", "text/csv"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "success",
               "details" => %{"file_id" => "recruit_file_456"}
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body("Last_Name,Email\nDoe,doe@example.com")

      {:ok, result} = Write.upload_file(input, "Candidates", service: :recruit)

      assert result["details"]["file_id"] == "recruit_file_456"
    end
  end

  describe "upload_file/3 validation" do
    test "rejects files larger than 25MB" do
      # Create a body larger than 25MB
      large_body = String.duplicate("x", 26 * 1024 * 1024)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(large_body)

      {:error, error} = Write.upload_file(input, "Leads")

      assert error.code == "FILE_SIZE_EXCEEDED"
      assert error.message =~ "exceeds maximum"
    end

    test "rejects non-binary body" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"not" => "binary"})

      {:error, error} = Write.upload_file(input, "Leads")

      assert error.code == "INVALID_FILE_BODY"
    end
  end

  describe "create_job/2 for CRM" do
    test "creates a bulk write job for CRM" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write"
        refute url =~ "write/file"

        body_map = Jason.decode!(body)
        assert body_map["operation"] == "insert"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "status" => "ADDED",
               "details" => %{"id" => "write_job_123"}
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
              %{"api_name" => "Last_Name", "index" => 0}
            ]
          }
        ]
      }

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(job_config)

      {:ok, result} = Write.create_job(input)

      assert result["status"] == "ADDED"
      assert result["details"]["id"] == "write_job_123"
    end
  end

  describe "create_job/2 for Recruit" do
    test "creates a bulk write job for Recruit" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/bulk/write"
        refute url =~ "write/file"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "status" => "ADDED",
               "details" => %{"id" => "recruit_write_job_456"}
             })
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"operation" => "insert", "resource" => []})

      {:ok, result} = Write.create_job(input, service: :recruit)

      assert result["details"]["id"] == "recruit_write_job_456"
    end
  end

  describe "get_job_status/3" do
    test "gets bulk write job status for CRM" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write/job_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"status" => "COMPLETED"})
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Write.get_job_status(input, "job_123")

      assert result["status"] == "COMPLETED"
    end

    test "gets bulk write job status for Recruit" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/v8/bulk/write/recruit_job_456"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"status" => "IN_PROGRESS"})
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Write.get_job_status(input, "recruit_job_456", service: :recruit)

      assert result["status"] == "IN_PROGRESS"
    end

    test "validates job_id" do
      input = InputRequest.new("test_token")
      {:error, error} = Write.get_job_status(input, "invalid/id")

      assert error =~ "path separators not allowed"
    end
  end
end
