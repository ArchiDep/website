defmodule ArchiDep.Accounts.Sessions do
  @moduledoc """
  User account management use cases to check and read session-related
  information.
  """

  use ArchiDep, :use_case
  use ArchiDep.Authorization

  alias ArchiDep.Accounts.Schemas.UserSession

  @spec fetch_active_sessions(Authentication.t()) :: list(UserSession.t())
  def fetch_active_sessions(auth),
    do:
      auth
      |> tap(&authorize!(:fetch_active_sessions, &1, %{}))
      |> Authentication.user_account_id()
      |> UserSession.fetch_active_sessions_by_user_account_id()

  @spec validate_session(String.t(), map) ::
          {:ok, UserSession.t()} | {:error, :session_not_found}
  def validate_session(token, metadata) do
    extracted_metadata = EventMetadata.extract(metadata)

    token
    |> UserSession.fetch_active_session_by_token()
    |> ok_then(&UserSession.touch(&1, extracted_metadata))
    |> ok_map(&Authentication.for_user_session(&1, extracted_metadata))
  end
end
