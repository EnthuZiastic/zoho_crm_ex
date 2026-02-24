defmodule ZohoAPI.MeetingTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZohoAPI.Meeting
  alias ZohoAPI.TokenCache

  setup :verify_on_exit!

  setup do
    name = :"meeting_test_#{:rand.uniform(100_000)}"
    {:ok, pid} = TokenCache.start_link(name: name)

    prev_config = Application.get_env(:zoho_api, :token_cache, [])
    Application.put_env(:zoho_api, :token_cache, name: name)

    on_exit(fn ->
      Application.put_env(:zoho_api, :token_cache, prev_config)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    TokenCache.put_token(:meeting, "test_meeting_token")
    assert TokenCache.get_token(:meeting) == "test_meeting_token"

    :ok
  end

  describe "create_session/2" do
    test "returns {:ok, session} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
        assert url =~ "12345/sessions.json"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{"session" => %{"meetingKey" => "mtg_abc", "joinLink" => "https://"}})
         }}
      end)

      assert {:ok, %{"meetingKey" => "mtg_abc"}} =
               Meeting.create_session("12345", %{"session" => %{"topic" => "Standup"}})
    end

    test "returns {:error, other} when response has no 'session' key (error shape fix)" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"message" => "unexpected"})
         }}
      end)

      assert {:error, _} = Meeting.create_session("12345", %{})
    end

    test "returns {:error, reason} for invalid zsoid" do
      assert {:error, reason} = Meeting.create_session("../bad", %{})
      assert is_binary(reason)
    end
  end

  describe "list_sessions/2" do
    test "returns {:ok, sessions} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "12345/sessions.json"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"sessions" => [%{"id" => "s1"}, %{"id" => "s2"}]})
         }}
      end)

      assert {:ok, [%{"id" => "s1"}, %{"id" => "s2"}]} = Meeting.list_sessions("12345")
    end

    test "returns {:error, reason} for invalid zsoid" do
      assert {:error, _} = Meeting.list_sessions("bad/zsoid")
    end
  end

  describe "delete_session/2" do
    test "returns :ok on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :delete, url, _body, _headers, _opts ->
        assert url =~ "12345/sessions/key_abc.json"

        {:ok,
         %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"message" => "deleted"})}}
      end)

      assert :ok = Meeting.delete_session("12345", "key_abc")
    end

    test "returns {:error, reason} for invalid meeting_key" do
      assert {:error, _} = Meeting.delete_session("12345", "bad/key")
    end
  end

  describe "get_participant_report/3" do
    test "returns {:ok, participants} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "12345/participant/key_abc.json"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"participants" => [%{"name" => "Alice"}]})
         }}
      end)

      assert {:ok, [%{"name" => "Alice"}]} =
               Meeting.get_participant_report("12345", "key_abc")
    end
  end

  describe "get_recordings/2" do
    test "returns {:ok, recordings} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "12345/recordings/key_abc.json"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"recordings" => [%{"url" => "https://rec"}]})
         }}
      end)

      assert {:ok, [%{"url" => "https://rec"}]} = Meeting.get_recordings("12345", "key_abc")
    end

    test "returns {:error, reason} for invalid zsoid" do
      assert {:error, _} = Meeting.get_recordings("../escape", "key_abc")
    end
  end

  describe "get_user_info/0" do
    test "returns {:ok, response} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert url =~ "user.json"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"userDetails" => %{"zsoid" => "12345"}})
         }}
      end)

      assert {:ok, %{"userDetails" => %{"zsoid" => "12345"}}} = Meeting.get_user_info()
    end
  end
end
