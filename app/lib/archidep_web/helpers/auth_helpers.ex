defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.ServerOwner

  @session_log_prefix_length 8

  @spec logged_in?(Authentication.t()) :: boolean()
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @spec root?(Authentication.t()) :: boolean()
  def root?(nil), do: false
  def root?(auth), do: Authentication.root?(auth)

  @spec same_user?(Authentication.t(), ServerOwner.t()) :: boolean()
  def same_user?(nil, _user), do: false

  def same_user?(%Authentication{principal_id: principal_id}, %ServerOwner{id: principal_id}),
    do: true

  def same_user?(_auth, _user), do: false

  @spec can_impersonate?(Authentication.t(), struct()) :: boolean()
  def can_impersonate?(nil, _user_account), do: false

  def can_impersonate?(
        %Authentication{
          principal_id: principal_id,
          impersonated_id: impersonated_id
        } = auth,
        %{id: user_account_id}
      ),
      do: root?(auth) and impersonated_id == nil and user_account_id != principal_id

  @spec impersonating?(Authentication.t()) :: boolean()
  def impersonating?(nil), do: false

  def impersonating?(%Authentication{impersonated_id: nil}),
    do: false

  def impersonating?(_auth), do: true

  @spec username(Authentication.t()) :: String.t() | nil
  defdelegate username(auth), to: Authentication

  @doc """
  Labels the log lines of the calling process with the first characters of the
  authenticated session's ID. That is enough to tell the lines of one browser
  from those of another, and it identifies a user only to someone who can read
  the sessions in the database.
  """
  @spec put_session_log_metadata(Authentication.t()) :: :ok
  def put_session_log_metadata(%Authentication{session_id: session_id}),
    do: Logger.metadata(session: String.slice(session_id, 0, @session_log_prefix_length))
end
