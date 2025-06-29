defmodule ArchiDep.Accounts.DeleteSession do
  @moduledoc """
  User account management use case for a user to delete one of their sessions
  (typically a session they logged into on another browser). An administrator
  can delete any user's sessions.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.SessionDeleted
  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserSession

  @spec delete_session(Authentication.t(), String.t()) ::
          {:ok, UserSession.t()} | {:error, :session_not_found}
  def delete_session(auth, id) do
    with :ok <- validate_uuid(id, :session_not_found),
         {:ok, session} <- UserSession.fetch_by_id(id) do
      authorize!(auth, Policy, :accounts, :delete_session, session)
      {:ok, _result} = store(session, auth)
      {:ok, session}
    end
  end

  defp store(session, auth) do
    %UserSession{user_account: user_account} = session

    Multi.new()
    |> delete(:user_session, session)
    |> insert(
      :stored_event,
      session |> SessionDeleted.new() |> new_event(auth) |> add_to_stream(user_account)
    )
    |> transaction()
  end
end
