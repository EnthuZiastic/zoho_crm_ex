defmodule ZohoAPI.Modules.Bulk.ReadTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Bulk.Read

  setup :verify_on_exit!

  describe "create_job/2 for CRM" do
    test "creates a bulk read job for CRM (default service)" do
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

      {:ok, result} = Read.create_job(input)

      assert result["status"] == "ADDED"
      assert result["details"]["id"] == "job_456"
    end

    test "creates a bulk read job for CRM with explicit service option" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/read"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body: Jason.encode!(%{"status" => "ADDED", "details" => %{"id" => "job_789"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"query" => %{}})

      {:ok, result} = Read.create_job(input, service: :crm)

      assert result["details"]["id"] == "job_789"
    end
  end

  describe "create_job/2 for Recruit" do
    test "creates a bulk read job for Recruit" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/bulk/v2/read"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        body_map = Jason.decode!(body)
        assert body_map["query"]["module"]["api_name"] == "Candidates"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "status" => "ADDED",
               "details" => %{"id" => "recruit_job_123"}
             })
         }}
      end)

      job_config = %{
        "query" => %{
          "module" => %{"api_name" => "Candidates"},
          "fields" => [
            %{"api_name" => "Last_Name"},
            %{"api_name" => "Email"}
          ]
        }
      }

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(job_config)

      {:ok, result} = Read.create_job(input, service: :recruit)

      assert result["status"] == "ADDED"
      assert result["details"]["id"] == "recruit_job_123"
    end

    test "uses correct region for Recruit bulk" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.com/recruit/bulk/v2/read"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body: Jason.encode!(%{"status" => "ADDED", "details" => %{"id" => "job_us"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_region(:com)
        |> InputRequest.with_body(%{"query" => %{}})

      {:ok, _result} = Read.create_job(input, service: :recruit)
    end
  end

  describe "get_job_status/3" do
    test "gets bulk read job status for CRM" do
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
      {:ok, result} = Read.get_job_status(input, "job_456")

      assert result["status"] == "COMPLETED"
      assert result["result"]["count"] == 1500
    end

    test "gets bulk read job status for Recruit" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "recruit.zoho.in/recruit/bulk/v2/read/recruit_job_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "IN_PROGRESS",
               "result" => %{}
             })
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Read.get_job_status(input, "recruit_job_123", service: :recruit)

      assert result["status"] == "IN_PROGRESS"
    end

    test "validates job_id" do
      input = InputRequest.new("test_token")
      {:error, error} = Read.get_job_status(input, "../../../etc/passwd")

      assert error =~ "path traversal not allowed"
    end
  end

  describe "edge cases" do
    test "handles invalid service option gracefully" do
      # Invalid service should raise FunctionClauseError since api_config_for_service
      # only matches :crm and :recruit
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{"query" => %{}})

      assert_raise FunctionClauseError, fn ->
        Read.create_job(input, service: :invalid)
      end
    end

    test "handles empty body for job creation" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, body, _headers, _opts ->
        body_map = Jason.decode!(body)
        assert body_map == %{}

        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: Jason.encode!(%{"code" => "INVALID_DATA", "message" => "query is required"})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{})

      # 400 responses return as error tuple
      {:error, error} = Read.create_job(input)

      assert error["code"] == "INVALID_DATA"
    end
  end
end
