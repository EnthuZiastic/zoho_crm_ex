defmodule ZohoCrm.Request do
  @moduledoc """
  handle HTTP request to Zoho CRM
  """
  @base_url "https://www.zohoapis.in"
  @version "v3"

  @enforce_keys [:api_type]
  @default_headers [
    {"content-type", "application/json"}
  ]
  defstruct [
    :path,
    :method,
    :headers,
    :body,
    :params,
    :api_type,
    base_url: @base_url,
    version: @version
  ]

  def new(api_type \\ "crm") do
    %__MODULE__{api_type: api_type}
  end

  def with_method(%__MODULE__{} = r, method) do
    %{r | method: method}
  end

  def set_base_url(%__MODULE__{} = r, base_url) do
    %{r | base_url: base_url}
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
    HTTPoison.request(r.method, url, body, r.headers)
  end

  def construct_url(%__MODULE__{} = r) do
    encoded_params = URI.encode_query(r.params)
    "#{r.base_url}/#{r.api_type}/#{r.version}/#{r.path}?#{encoded_params}"
  end
end
