defmodule ZohoAPI.Bookings do
  @moduledoc """
  High-level Zoho Bookings client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  appointment attributes as maps — no token handling required.

  Note: Booking API uses form-encoded requests. Pass a plain map and this module
  handles the encoding internally.

  Responses are trimmed: the Zoho `response.returnvalue` is extracted and returned
  directly as `{:ok, result}`.

  ## Examples

      {:ok, result} = ZohoAPI.Bookings.book_appointment(%{service_id: "...", from_time: "..."})
      {:ok, result} = ZohoAPI.Bookings.reschedule_appointment(%{booking_id: "...", from_time: "..."})
      {:ok, result} = ZohoAPI.Bookings.update_appointment(%{booking_id: "...", action: "completed"})
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Bookings, as: BookingsAPI
  alias ZohoAPI.TokenCache

  @spec book_appointment(map()) :: {:ok, map()} | {:error, any()}
  def book_appointment(attrs) when is_map(attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:bookings),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, {:form, Map.to_list(attrs)})
           |> BookingsAPI.book_appointment() do
      parse_booking_response(raw)
    end
  end

  @spec reschedule_appointment(map()) :: {:ok, map()} | {:error, any()}
  def reschedule_appointment(attrs) when is_map(attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:bookings),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, {:form, Map.to_list(attrs)})
           |> BookingsAPI.reschedule_appointment() do
      parse_booking_response(raw)
    end
  end

  @spec update_appointment(map()) :: {:ok, map()} | {:error, any()}
  def update_appointment(attrs) when is_map(attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:bookings),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, {:form, Map.to_list(attrs)})
           |> BookingsAPI.update_appointment() do
      parse_booking_response(raw)
    end
  end

  @spec get_appointment(map()) :: {:ok, map()} | {:error, any()}
  def get_appointment(params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:bookings),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> BookingsAPI.get_appointment() do
      parse_booking_response(raw)
    end
  end

  # Extracts returnvalue from Zoho Bookings response wrapper:
  # {:ok, %{"response" => %{"returnvalue" => result, "status" => "success"}}}
  defp parse_booking_response(%{"response" => %{"returnvalue" => result, "status" => "success"}}),
    do: {:ok, result}

  defp parse_booking_response(%{
         "response" => %{"returnvalue" => %{"status" => "failure"}} = resp
       }),
       do: {:error, resp}

  defp parse_booking_response(other),
    do: {:error, other}
end
