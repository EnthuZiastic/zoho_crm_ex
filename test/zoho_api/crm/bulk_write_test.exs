defmodule ZohoAPI.CRM.BulkWriteTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZohoAPI.CRM.BulkWrite
  alias ZohoAPI.TokenCache

  setup :verify_on_exit!

  setup do
    name = :"crm_bulk_write_test_#{:rand.uniform(100_000)}"
    {:ok, pid} = TokenCache.start_link(name: name)

    prev_config = Application.get_env(:zoho_api, :token_cache, [])
    Application.put_env(:zoho_api, :token_cache, name: name)

    on_exit(fn ->
      Application.put_env(:zoho_api, :token_cache, prev_config)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    TokenCache.put_token(:crm, "test_crm_token")
    assert TokenCache.get_token(:crm) == "test_crm_token"

    :ok
  end

  describe "create_job/3" do
    test "returns error for empty records list" do
      assert {:error, _} = BulkWrite.create_job("Leads", [])
    end

    test "returns error when records exceed 25,000 limit" do
      records = List.duplicate(%{"Last_Name" => "Smith"}, 25_001)
      assert {:error, _} = BulkWrite.create_job("Leads", records)
    end

    test "happy path: uploads file and creates job, returns job_id" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write/file"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "status" => "success",
               "details" => %{"file_id" => "file_abc"}
             })
         }}
      end)

      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write"
        refute url =~ "/file"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body:
             Jason.encode!(%{
               "status" => "ADDED",
               "details" => %{"id" => "job_xyz"}
             })
         }}
      end)

      records = [%{"Last_Name" => "Smith", "Email" => "smith@example.com"}]
      assert {:ok, "job_xyz"} = BulkWrite.create_job("Leads", records)
    end
  end

  describe "poll_until_complete/2" do
    test "returns {:error, :timeout} when max_attempts is 0" do
      assert {:error, :timeout} = BulkWrite.poll_until_complete("job_123", max_attempts: 0)
    end

    test "returns {:ok, status} when job state is COMPLETED" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write/job_completed"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"state" => "COMPLETED", "result" => %{"added_count" => 50}})
         }}
      end)

      assert {:ok, %{"state" => "COMPLETED"}} =
               BulkWrite.poll_until_complete("job_completed",
                 max_attempts: 1,
                 poll_interval: 0
               )
    end

    test "returns {:error, status} when job state is FAILED" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "crm/bulk/v8/write/job_failed"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"state" => "FAILED", "message" => "Job failed"})
         }}
      end)

      assert {:error, %{"state" => "FAILED"}} =
               BulkWrite.poll_until_complete("job_failed",
                 max_attempts: 1,
                 poll_interval: 0
               )
    end
  end
end
