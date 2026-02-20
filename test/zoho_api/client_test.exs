defmodule ZohoAPI.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoAPI.Client
  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  setup :verify_on_exit!

  describe "send/2" do
    test "successful request returns {:ok, data}" do
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"data": [{"id": "123"}]})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("test_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input = InputRequest.new("test_token")

      assert {:ok, %{"data" => [%{"id" => "123"}]}} = Client.send(request, input)
    end

    test "error response returns {:error, data}" do
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 400, body: ~s({"error": "bad request"})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("test_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input = InputRequest.new("test_token")

      assert {:error, %{"error" => "bad request"}} = Client.send(request, input)
    end

    test "retries on 500 error" do
      counter = :counters.new(1, [:atomics])

      ZohoAPI.HTTPClientMock
      |> expect(:request, 2, fn :get, _url, _body, _headers, _opts ->
        :counters.add(counter, 1, 1)
        current = :counters.get(counter, 1)

        if current < 2 do
          {:ok, %HTTPoison.Response{status_code: 500, body: ~s({"error": "server error"})}}
        else
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"data": []})}}
        end
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("test_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_retry_opts(base_delay_ms: 1)

      assert {:ok, %{"data" => []}} = Client.send(request, input)
      assert :counters.get(counter, 1) == 2
    end

    test "401 without refresh token returns error" do
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 401, body: ~s({"error": "unauthorized"})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("expired_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input = InputRequest.new("expired_token")

      assert {:error, %{"error" => "unauthorized"}} = Client.send(request, input)
    end

    test "401 with refresh token attempts token refresh" do
      # First call returns 401, second call (after refresh) succeeds
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, url, _body, _headers, _opts ->
        if String.contains?(url, "Leads") do
          {:ok, %HTTPoison.Response{status_code: 401, body: ~s({"error": "unauthorized"})}}
        end
      end)
      |> expect(:request, fn :post, url, _body, _headers, _opts ->
        if String.contains?(url, "oauth") do
          {:ok,
           %HTTPoison.Response{
             status_code: 200,
             body: ~s({"access_token": "new_token", "expires_in": 3600})
           }}
        end
      end)
      |> expect(:request, fn :get, url, _body, headers, _opts ->
        # Verify new token is used
        auth_header = List.keyfind(headers, "Authorization", 0)
        assert auth_header == {"Authorization", "Zoho-oauthtoken new_token"}

        if String.contains?(url, "Leads") do
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"data": [{"id": "123"}]})}}
        end
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("expired_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input =
        InputRequest.new("expired_token")
        |> InputRequest.with_refresh_token("valid_refresh_token")

      assert {:ok, %{"data" => [%{"id" => "123"}]}} = Client.send(request, input)
    end

    test "401 with refresh token calls on_token_refresh callback" do
      test_pid = self()

      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 401, body: ~s({"error": "unauthorized"})}}
      end)
      |> expect(:request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: ~s({"access_token": "new_token", "expires_in": 3600})
         }}
      end)
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"data": []})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("expired_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      callback = fn new_token ->
        send(test_pid, {:token_refreshed, new_token})
      end

      input =
        InputRequest.new("expired_token")
        |> InputRequest.with_refresh_token("valid_refresh_token")
        |> InputRequest.with_on_token_refresh(callback)

      assert {:ok, _} = Client.send(request, input)
      assert_received {:token_refreshed, "new_token"}
    end

    test "token refresh failure returns error" do
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 401, body: ~s({"error": "unauthorized"})}}
      end)
      |> expect(:request, fn :post, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 400, body: ~s({"error": "invalid_grant"})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("expired_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input =
        InputRequest.new("expired_token")
        |> InputRequest.with_refresh_token("invalid_refresh_token")

      assert {:error, :token_refresh_failed} = Client.send(request, input)
    end
  end

  describe "send_without_rate_limit/2" do
    test "executes request without rate limiting" do
      ZohoAPI.HTTPClientMock
      |> expect(:request, fn :get, _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"data": []})}}
      end)

      request =
        Request.new("crm")
        |> Request.set_access_token("test_token")
        |> Request.with_method(:get)
        |> Request.with_path("Leads")

      input = InputRequest.new("test_token")

      assert {:ok, %{"data" => []}} = Client.send_without_rate_limit(request, input)
    end
  end
end
