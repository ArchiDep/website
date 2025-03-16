defmodule ArchiDep.Accounts.LogOut do
  @moduledoc """
  User account management use case for a user to log out (i.e. deleting one of
  their sessions).
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.UserLoggedOut
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication

  @spec log_out(Authentication.t()) :: :ok | {:error, :session_not_found}
  def log_out(auth) do
    token = Authentication.session_token(auth)

    with {:ok, session} <- fetch_session_by_token(token) do
      {:ok, _multi} = delete_session(session, auth)
      :ok
    end
  end

  defp fetch_session_by_token(token), do: UserSession.fetch_active_session_by_token(token)

  defp delete_session(session, auth) do
    %UserSession{user_account: user_account} = session

    Multi.new()
    |> delete(:user_session, session)
    |> insert(
      :stored_event,
      session
      |> UserLoggedOut.new()
      |> new_event(auth)
      |> add_to_stream(user_account)
    )
    |> transaction()
  end
end
