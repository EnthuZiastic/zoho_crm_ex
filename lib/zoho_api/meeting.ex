defmodule ZohoAPI.Meeting do
  @moduledoc """
  High-level Zoho Meeting client.

  Manages token fetching automatically via `ZohoAPI.TokenCache`. Callers
  provide `zsoid` (the Zoho organisation/user ID) and session parameters
  directly — no token handling required.

  You can retrieve your `zsoid` once via `get_user_info/0` and store it
  in your application config.

  ## Configuration

      config :zoho_api, :meeting,
        client_id:     {:system, "ZOHO_MEETING_CLIENT_ID"},
        client_secret: {:system, "ZOHO_MEETING_CLIENT_SECRET"},
        refresh_token: {:system, "ZOHO_MEETING_REFRESH_TOKEN"},
        region:        :com,
        zsoid:         {:system, "ZOHO_MEETING_ZSOID"}

  ## Examples

      {:ok, user}    = ZohoAPI.Meeting.get_user_info()
      {:ok, meeting} = ZohoAPI.Meeting.create_session(zsoid, %{
        "session" => %{
          "topic"     => "Team Standup",
          "presenter" => 123456789,
          "duration"  => 3_600_000,
          "timezone"  => "UTC"
        }
      })
      {:ok, sessions} = ZohoAPI.Meeting.list_sessions(zsoid)
      :ok             = ZohoAPI.Meeting.delete_session(zsoid, meeting_key)
      {:ok, report}   = ZohoAPI.Meeting.get_participant_report(zsoid, meeting_key)
      {:ok, recs}     = ZohoAPI.Meeting.get_recordings(zsoid, meeting_key)
  """

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Modules.Meeting, as: MeetingAPI
  alias ZohoAPI.TokenCache

  @type zsoid :: String.t()
  @type meeting_key :: String.t()

  @doc """
  Returns the authenticated user's Zoho Meeting profile.

  Useful for retrieving your `zsoid` (found at `userDetails.zsoid` in the
  response), which is required by all other functions in this module.
  """
  @spec get_user_info() :: {:ok, map()} | {:error, any()}
  def get_user_info do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting) do
      token
      |> InputRequest.new(nil)
      |> MeetingAPI.get_user_info()
    end
  end

  @doc """
  Creates a new meeting session.

  `session_params` must be wrapped under a `"session"` key:

      %{
        "session" => %{
          "topic"     => "Monthly Marketing Meeting",
          "presenter" => 123456789,
          "duration"  => 3_600_000,
          "timezone"  => "UTC"
        }
      }

  Returns `{:ok, %{"meetingKey" => ..., "joinLink" => ...}}` on success.
  """
  @spec create_session(zsoid(), map()) :: {:ok, map()} | {:error, any()}
  def create_session(zsoid, session_params) do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, %{}, session_params)
           |> MeetingAPI.create_session(zsoid) do
      case raw do
        %{"session" => session} -> {:ok, session}
        other -> {:ok, other}
      end
    end
  end

  @doc """
  Lists meeting sessions for the organisation.

  ## Options (passed as query params map)

    - `"listtype"` — `"all"` | `"past"` | `"today"` | `"upcoming"` (default `"upcoming"`)
    - `"index"`    — starting record index (default `1`)
    - `"count"`    — records per page (default `25`)

  Returns `{:ok, sessions}` where `sessions` is a list of session maps.
  """
  @spec list_sessions(zsoid(), map()) :: {:ok, list(map())} | {:error, any()}
  def list_sessions(zsoid, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> MeetingAPI.list_sessions(zsoid) do
      {:ok, Map.get(raw, "sessions", [])}
    end
  end

  @doc """
  Deletes (cancels) a meeting session.
  """
  @spec delete_session(zsoid(), meeting_key()) :: :ok | {:error, any()}
  def delete_session(zsoid, meeting_key) do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting),
         {:ok, _raw} <-
           token
           |> InputRequest.new(nil)
           |> MeetingAPI.delete_session(zsoid, meeting_key) do
      :ok
    end
  end

  @doc """
  Fetches the participant attendance report for a completed meeting.

  ## Options (passed as query params map)

    - `"index"` — starting record index (default `1`)
    - `"count"` — records per page (default `100`)

  Returns `{:ok, participants}` where `participants` is a list of attendee maps.
  """
  @spec get_participant_report(zsoid(), meeting_key(), map()) ::
          {:ok, list(map())} | {:error, any()}
  def get_participant_report(zsoid, meeting_key, params \\ %{}) do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil, params)
           |> MeetingAPI.get_participant_report(zsoid, meeting_key) do
      {:ok, Map.get(raw, "participants", [])}
    end
  end

  @doc """
  Fetches the recording list for a completed meeting.

  Returns `{:ok, recordings}` where `recordings` is a list of recording maps,
  each containing a download URL.
  """
  @spec get_recordings(zsoid(), meeting_key()) :: {:ok, list(map())} | {:error, any()}
  def get_recordings(zsoid, meeting_key) do
    with {:ok, token} <- TokenCache.get_or_refresh(:meeting),
         {:ok, raw} <-
           token
           |> InputRequest.new(nil)
           |> MeetingAPI.get_recordings(zsoid, meeting_key) do
      {:ok, Map.get(raw, "recordings", [])}
    end
  end
end
