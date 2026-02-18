defmodule ZohoAPI.Bookings do
  @moduledoc """
  High-level Zoho Bookings client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers provide
  appointment attributes as maps — no token handling required.

  Note: Booking API uses form-encoded requests. Pass a plain map and this module
  handles the encoding internally.

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
    with {:ok, token} <- TokenCache.get_or_refresh(:booking) do
      token
      |> InputRequest.new(nil, %{}, {:form, Enum.map(attrs, & &1)})
      |> BookingsAPI.book_appointment()
    end
  end

  @spec reschedule_appointment(map()) :: {:ok, map()} | {:error, any()}
  def reschedule_appointment(attrs) when is_map(attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:booking) do
      token
      |> InputRequest.new(nil, %{}, {:form, Enum.map(attrs, & &1)})
      |> BookingsAPI.reschedule_appointment()
    end
  end

  @spec update_appointment(map()) :: {:ok, map()} | {:error, any()}
  def update_appointment(attrs) when is_map(attrs) do
    with {:ok, token} <- TokenCache.get_or_refresh(:booking) do
      token
      |> InputRequest.new(nil, %{}, {:form, Enum.map(attrs, & &1)})
      |> BookingsAPI.update_appointment()
    end
  end

  @spec get_appointment(map()) :: {:ok, map()} | {:error, any()}
  def get_appointment(params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:booking) do
      token
      |> InputRequest.new(nil, params)
      |> BookingsAPI.get_appointment()
    end
  end
end
