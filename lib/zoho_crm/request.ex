defmodule ZohoCrm.Request do
  @moduledoc """
  handle HTTP request to Zoho CRM
  """
  @base_url "https://www.zohoapis.in"
  @version "v3"

  @default_headers %{
    "Content-Type" => "application/json"
  }

  @enforce_keys [:api_type]
  defstruct [
    :path,
    :method,
    :api_type,
    params: %{},
    body: %{},
    headers: @default_headers,
    base_url: @base_url,
    version: @version
  ]

  @doc """
  Initialize Request struct

  ## Example
      iex> Request.new(api_type \\ "crm")
  """
  @spec new(String.t()) :: __MODULE__
  def new(api_type \\ "crm") do
    %__MODULE__{api_type: api_type}
  end

  def set_api_type(%__MODULE__{} = r, api_type) do
    %{r | api_type: api_type}
  end

  def with_version(%__MODULE__{} = r, version) do
    %{r | version: version}
  end

  def with_method(%__MODULE__{} = r, method) do
    %{r | method: method}
  end

  def set_base_url(%__MODULE__{} = r, base_url) do
    %{r | base_url: base_url}
  end

  def set_headers(%__MODULE__{} = r, headers) when is_map(headers) do
    headers =
      @default_headers
      |> Map.merge(r.headers)
      |> Map.merge(headers)

    %{r | headers: headers}
  end

  def set_access_token(%__MODULE__{} = r, access_token) do
    token = %{
      "Authorization" => "Zoho-oauthtoken #{access_token}"
    }

    %{r | headers: Map.merge(r.headers, token)}
  end

  def with_path(%__MODULE__{} = r, path) do
    %{r | path: path}
  end

  def with_body(%__MODULE__{} = r, body) do
    %{r | body: body}
  end

  def with_params(%__MODULE__{} = r, params) do
    %{r | params: params}
  end

  def send(%__MODULE__{} = r) do
    url = construct_url(r)
    body = if is_map(r.body), do: Jason.encode!(r.body), else: r.body

    r.method
    |> HTTPoison.request(url, body, r.headers)
    |> handle_response()
  end

  defp handle_response({:ok, %HTTPoison.Response{body: body, status_code: status_code}})
       when status_code in [200, 201, 202, 203, 204, 205, 206] do
    {:ok, json_or_value(body)}
  end

  defp handle_response({:ok, %HTTPoison.Response{body: body}}) do
    {:error, json_or_value(body)}
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, json_or_value(reason)}
  end

  defp json_or_value(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed_value} -> parsed_value
      _ -> data
    end
  end

  defp json_or_value(data), do: data

  def construct_url(%__MODULE__{api_type: "crm"} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}/#{r.api_type}/#{r.version}/#{r.path}?#{encoded_params}"
  end

  def construct_url(%__MODULE__{api_type: "recruit"} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}/#{r.api_type}/#{r.version}/#{r.path}?#{encoded_params}"
  end

  def construct_url(%__MODULE__{api_type: "bookings"} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}/#{r.api_type}/#{r.version}/#{r.path}?#{encoded_params}"
  end

  def construct_url(%__MODULE__{api_type: "oauth"} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}/#{r.api_type}/#{r.version}/#{r.path}?#{encoded_params}"
  end

  def construct_url(%__MODULE__{api_type: "portal"} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}#{r.path}?#{encoded_params}"
  end
end
