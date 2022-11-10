defmodule ZohoCrm.Request do
  @moduledoc """
  handle HTTP request to Zoho CRM
  """
  @base_url "https://www.zohoapis.in/crm"
  @version "v3"

  @default_headers [
    {"content-type", "application/json"}
  ]
  defstruct [
    :path,
    :method,
    :headers,
    :body,
    :params,
    base_url: @base_url,
    version: @version
  ]

  def new do
    %__MODULE__{}
  end

  def with_method(%__MODULE__{} = r, method) do
    %{r | method: method}
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
    "#{r.base_url}/#{r.version}/#{r.path}?#{r.params}"
  end
end
