defmodule ArchiDep.Accounts.UseCases.LogOut do
  @moduledoc """
  User account management use case for a user to log out (i.e. deleting one of
  their sessions).
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.UserLoggedOut
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.Clock

  @spec log_out(Authentication.t()) :: :ok | {:error, :session_not_found}
  def log_out(auth) do
    # By ID rather than by token: the session being logged out is the one the
    # authentication names, and its ID identifies it without the caller having
    # to still hold the token, which a channel-authenticated caller does not
    # (see `ArchiDep.Authentication.session_token/1`).
    id = Authentication.session_id(auth)
    now = Clock.now()

    with {:ok, session} <- UserSession.fetch_active_session_by_id(id, now) do
      {:ok, _multi} = delete_session(session, auth, now)

      :telemetry.execute([:archidep, :accounts, :auth, :logout], %{}, %{
        principal_id: Authentication.principal_id(auth)
      })

      :ok
    end
  end

  defp delete_session(session, auth, now) do
    %UserSession{user_account: user_account} = session

    Multi.new()
    |> delete(:user_session, session)
    |> insert(
      :stored_event,
      session
      |> UserLoggedOut.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(user_account)
    )
    |> transaction()
  end
end
