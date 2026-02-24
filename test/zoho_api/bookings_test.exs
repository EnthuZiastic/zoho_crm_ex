defmodule ZohoAPI.BookingsTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZohoAPI.Bookings
  alias ZohoAPI.TokenCache

  setup :verify_on_exit!

  setup do
    name = :"bookings_test_#{:rand.uniform(100_000)}"
    {:ok, pid} = TokenCache.start_link(name: name)

    prev_config = Application.get_env(:zoho_api, :token_cache, [])
    Application.put_env(:zoho_api, :token_cache, name: name)

    on_exit(fn ->
      Application.put_env(:zoho_api, :token_cache, prev_config)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    TokenCache.put_token(:bookings, "test_bookings_token")
    assert TokenCache.get_token(:bookings) == "test_bookings_token"

    :ok
  end

  describe "book_appointment/1" do
    test "returns {:ok, result} on success response" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "returnvalue" => %{"booking_id" => "appt_123"},
                 "status" => "success"
               }
             })
         }}
      end)

      assert {:ok, %{"booking_id" => "appt_123"}} =
               Bookings.book_appointment(%{service_id: "svc_1", from_time: "2024-01-01 10:00"})
    end

    test "returns {:error, resp} on failure returnvalue status" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "returnvalue" => %{"status" => "failure", "message" => "Slot not available"},
                 "status" => "failure"
               }
             })
         }}
      end)

      assert {:error, _} = Bookings.book_appointment(%{service_id: "svc_1"})
    end

    test "returns {:error, other} on unexpected response shape" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"error" => "Something went wrong"})
         }}
      end)

      assert {:error, _} = Bookings.book_appointment(%{service_id: "svc_1"})
    end
  end

  describe "reschedule_appointment/1" do
    test "returns {:error, resp} on failure status" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "returnvalue" => %{"status" => "failure", "message" => "Cannot reschedule"},
                 "status" => "failure"
               }
             })
         }}
      end)

      assert {:error, _} = Bookings.reschedule_appointment(%{booking_id: "appt_1"})
    end
  end

  describe "update_appointment/1" do
    test "returns {:error, other} on unexpected response shape" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :post, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"error" => "Update failed"})
         }}
      end)

      assert {:error, _} = Bookings.update_appointment(%{booking_id: "appt_1", action: "cancel"})
    end
  end

  describe "get_appointment/1" do
    test "returns {:ok, result} on success" do
      expect(ZohoAPI.HTTPClientMock, :request, fn :get, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "response" => %{
                 "returnvalue" => %{"id" => "appt_456", "status" => "booked"},
                 "status" => "success"
               }
             })
         }}
      end)

      assert {:ok, %{"id" => "appt_456"}} = Bookings.get_appointment(%{booking_id: "appt_456"})
    end
  end
end
