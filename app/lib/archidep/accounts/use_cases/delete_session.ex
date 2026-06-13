defmodule ArchiDep.Accounts.UseCases.DeleteSession do
  @moduledoc """
  User account management use case for a user to delete one of their sessions
  (typically a session they logged into on another browser). An administrator
  can delete any user's sessions.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.SessionDeleted
  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Clock

  @spec delete_session(Authentication.t(), String.t()) ::
          {:ok, UserSession.t()} | {:error, :session_not_found}
  def delete_session(auth, id) do
    now = Clock.now()

    with :ok <- validate_uuid(id, :session_not_found),
         {:ok, session} <- UserSession.fetch_by_id(id),
         :ok <- authorize(auth, Policy, :accounts, :delete_session, session) do
      {:ok, _result} = store(session, auth, now)
      {:ok, session}
    else
      {:error, :session_not_found} ->
        {:error, :session_not_found}

      # An unauthorized deletion is masked as not-found so the use case never
      # leaks whether a session the caller may not touch exists.
      {:error, {:access_denied, :accounts, :delete_session}} ->
        {:error, :session_not_found}
    end
  end

  defp store(session, auth, now) do
    %UserSession{user_account: user_account} = session

    Multi.new()
    |> delete(:user_session, session)
    |> insert(
      :stored_event,
      session
      |> SessionDeleted.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(user_account)
    )
    |> transaction()
  end
end
