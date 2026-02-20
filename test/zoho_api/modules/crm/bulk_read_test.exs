defmodule ZohoAPI.Modules.CRM.BulkReadTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.CRM.BulkRead

  setup :verify_on_exit!

  describe "create_job/1" do
    test "creates a bulk read job" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
        assert url =~ "crm/bulk/v8/read"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        body_map = Jason.decode!(body)
        assert body_map["query"]["module"]["api_name"] == "Leads"

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
        "query" => %{
          "module" => %{"api_name" => "Leads"},
          "fields" => [
            %{"api_name" => "Last_Name"},
            %{"api_name" => "Email"}
          ]
        }
      }

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(job_config)

      {:ok, result} = BulkRead.create_job(input)

      assert result["status"] == "ADDED"
      assert result["details"]["id"] == "job_456"
    end
  end

  describe "get_job_status/2" do
    test "gets bulk read job status" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/read/job_456"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "COMPLETED",
               "result" => %{
                 "download_url" => "https://example.com/download",
                 "count" => 1500,
                 "more_records" => false
               }
             })
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = BulkRead.get_job_status(input, "job_456")

      assert result["status"] == "COMPLETED"
      assert result["result"]["count"] == 1500
    end
  end
end
