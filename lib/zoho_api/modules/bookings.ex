defmodule ZohoAPI.Modules.Bookings do
  @moduledoc """
  This module handle Zoho Booking API
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @api_type "bookings"
  @version "v1"

  @form_content_type %{
    "Content-Type" => "application/x-www-form-urlencoded"
  }

  @spec get_appointment(InputRequest.t()) :: {:error, any} | {:ok, any}
  def get_appointment(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("/json/appointment")
    |> Request.with_params(r.query_params)
    |> Request.send()
  end

  @spec book_appointment(InputRequest.t()) :: {:error, any} | {:ok, any}
  def book_appointment(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path("/json/appointment")
    |> Request.with_body(r.body)
    |> Request.set_headers(@form_content_type)
    |> Request.send()
  end

  @spec update_appointment(InputRequest.t()) :: {:error, any} | {:ok, any}
  def update_appointment(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path("/json/updateappointment")
    |> Request.with_body(r.body)
    |> Request.set_headers(@form_content_type)
    |> Request.send()
  end

  @spec reschedule_appointment(InputRequest.t()) :: {:error, any} | {:ok, any}
  def reschedule_appointment(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path("/json/rescheduleappointment")
    |> Request.with_body(r.body)
    |> Request.set_headers(@form_content_type)
    |> Request.send()
  end

  @spec add_staff(InputRequest.t()) :: {:error, any} | {:ok, any}
  def add_staff(%InputRequest{} = ir) do
    construct_request(ir)
    |> Request.with_method(:post)
    |> Request.with_path("/json/addstaff")
    |> Request.with_body(ir.body)
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = ir) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.set_access_token(ir.access_token)
  end
end
