defmodule ArchiDep.Accounts.Sessions do
  @moduledoc """
  User account management use cases to check and read session-related
  information.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.ClientMetadata

  @spec fetch_active_sessions(Authentication.t()) :: list(UserSession.t())
  def fetch_active_sessions(auth),
    do:
      auth
      |> authorize!(Policy, :accounts, :fetch_active_sessions, nil)
      |> Authentication.user_account_id()
      |> UserSession.fetch_active_sessions_by_user_account_id()

  @spec validate_session(String.t(), ClientMetadata.t()) ::
          {:ok, Authentication.t()} | {:error, :session_not_found}
  def validate_session(token, client_metadata) do
    with {:ok, session} <- UserSession.fetch_active_session_by_token(token),
         {:ok, touched_session} <- UserSession.touch(session, client_metadata) do
      {:ok, Authentication.for_user_session(touched_session, client_metadata)}
    end
  end

  @spec user_account(Authentication.t()) :: UserAccount.t()
  def user_account(auth) do
    auth
    |> Authentication.user_account_id()
    |> UserAccount.get_with_switch_edu_id!()
  end
end
