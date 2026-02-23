defmodule ZohoAPI.Modules.Meeting do
  @moduledoc """
  Low-level Zoho Meeting API client.

  Handles HTTP requests to the Zoho Meeting REST API v2. Each function
  accepts an `%InputRequest{}` (carrying the access token and optional
  query params) plus any path-level identifiers required by the endpoint.

  The `zsoid` (Zoho org/user ID) is required by most endpoints and must
  be provided by the caller. You can obtain it once via `get_user_info/1`
  and cache it in your application config.
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Request

  @api_type "meeting"
  @version "v2"

  @type zsoid :: String.t()
  @type meeting_key :: String.t()

  @doc """
  Fetches the authenticated user's Zoho Meeting profile.

  Response includes `userDetails.zsoid`, which is required by all other
  Meeting API endpoints.
  """
  @spec get_user_info(InputRequest.t()) :: {:ok, map()} | {:error, any()}
  def get_user_info(%InputRequest{} = r) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("user.json")
    |> Request.send()
  end

  @doc """
  Creates a new meeting session.

  The `session_params` map should be wrapped under a `"session"` key:

      %{
        "session" => %{
          "topic" => "Team Standup",
          "presenter" => 123456789,
          "duration" => 3_600_000,
          "timezone" => "UTC"
        }
      }

  On success returns `{:ok, %{"session" => %{"meetingKey" => ..., "joinLink" => ...}}}`.
  """
  @spec create_session(InputRequest.t(), zsoid()) :: {:ok, map()} | {:error, any()}
  def create_session(%InputRequest{} = r, zsoid) do
    construct_request(r)
    |> Request.with_method(:post)
    |> Request.with_path("#{zsoid}/sessions.json")
    |> Request.with_body(r.body)
    |> Request.send()
  end

  @doc """
  Lists meeting sessions for the given organisation.

  Accepted query params (pass via `InputRequest` query_params):
    - `listtype` — `"all"` | `"past"` | `"today"` | `"upcoming"` (default `"upcoming"`)
    - `index`    — starting record index (default `1`)
    - `count`    — number of records to return (default `25`)
  """
  @spec list_sessions(InputRequest.t(), zsoid()) :: {:ok, map()} | {:error, any()}
  def list_sessions(%InputRequest{} = r, zsoid) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{zsoid}/sessions.json")
    |> Request.with_params(r.query_params)
    |> Request.send()
  end

  @doc """
  Deletes (cancels) a meeting session.
  """
  @spec delete_session(InputRequest.t(), zsoid(), meeting_key()) ::
          {:ok, map()} | {:error, any()}
  def delete_session(%InputRequest{} = r, zsoid, meeting_key) do
    construct_request(r)
    |> Request.with_method(:delete)
    |> Request.with_path("#{zsoid}/sessions/#{meeting_key}.json")
    |> Request.send()
  end

  @doc """
  Fetches the participant attendance report for a completed meeting.

  Accepted query params:
    - `index` — starting record index (default `1`)
    - `count` — number of records to return (default `100`)
  """
  @spec get_participant_report(InputRequest.t(), zsoid(), meeting_key()) ::
          {:ok, map()} | {:error, any()}
  def get_participant_report(%InputRequest{} = r, zsoid, meeting_key) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{zsoid}/participant/#{meeting_key}.json")
    |> Request.with_params(r.query_params)
    |> Request.send()
  end

  @doc """
  Fetches the recording list for a completed meeting.
  """
  @spec get_recordings(InputRequest.t(), zsoid(), meeting_key()) ::
          {:ok, map()} | {:error, any()}
  def get_recordings(%InputRequest{} = r, zsoid, meeting_key) do
    construct_request(r)
    |> Request.with_method(:get)
    |> Request.with_path("#{zsoid}/recordings/#{meeting_key}.json")
    |> Request.send()
  end

  defp construct_request(%InputRequest{} = r) do
    Request.new(@api_type)
    |> Request.with_version(@version)
    |> Request.set_access_token(r.access_token)
  end
end
