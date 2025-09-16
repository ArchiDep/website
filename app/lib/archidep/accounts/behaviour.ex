defmodule ArchiDep.Accounts.Behaviour do
  @moduledoc false

  use ArchiDep, :context_behaviour

  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types

  @doc """
  Logs in the user account with the specified Switch edu-ID, creating a new
  session. If no user account exists for that Switch edu-ID, a new user account
  is registered.
  """
  callback(
    log_in_or_register_with_switch_edu_id(
      data: Types.switch_edu_id_login_data(),
      meta: map
    ) ::
      {:ok, Authentication.t()}
      | {:error, :unauthorized_switch_edu_id}
  )

  @doc """
  Logs in a user account with the specified login link token, creating a new
  session. If that login linked corresponds to a preregistered user and no user
  account yet exists for that user, a new user account is registered.
  """
  callback(
    log_in_or_register_with_link(
      token: binary(),
      meta: map
    ) ::
      {:ok, Authentication.t()} | {:error, :invalid_link}
  )

  @doc """
  Authenticates using the specified session token. The token must correspond to
  an active session.
  """
  callback(
    validate_session_token(token: String.t(), meta: map) ::
      {:ok, Authentication.t()} | {:error, :session_not_found}
  )

  @doc """
  Authenticates using the specified session ID. The ID must be that of an active
  session.
  """
  callback(
    validate_session_id(id: UUID.t(), meta: map) ::
      {:ok, Authentication.t()} | {:error, :session_not_found}
  )

  @doc """
  Returns the list of active sessions for the currently authenticated user.
  """
  callback(fetch_active_sessions(auth: Authentication.t()) :: list(UserSession.t()))

  @doc """
  Impersonates the specified user account. As long as this is active, that
  session will behave as if the specified user account is the logged-in user.
  """
  callback(
    impersonate(auth: Authentication.t(), user_id: UUID.t()) ::
      {:ok, UserAccount.t()} | {:error, :user_account_not_found} | {:error, :unauthorized}
  )

  @doc """
  Stops impersonating a user account, returning to the original session.
  """
  callback(stop_impersonating(auth: Authentication.t()) :: :ok | {:error, :unauthorized})

  @doc """
  Deletes the specified session.
  """
  callback(
    delete_session(auth: Authentication.t(), id: String.t()) ::
      {:ok, UserSession.t()} | {:error, :session_not_found}
  )

  @doc """
  Fetches the user account corresponding to the current authentication.
  """
  callback(user_account(auth: Authentication.t()) :: UserAccount.t())

  @doc """
  Logs out a user account.
  """
  callback(log_out(auth: Authentication.t()) :: :ok | {:error, :session_not_found})

  @doc """
  Creates a new login link for the specified preregistered user.
  """
  callback(
    create_login_link_for_preregistered_user(
      auth: Authentication.t(),
      preregistered_user_id: UUID.t()
    ) :: {:ok, LoginLink.t()} | {:error, :preregistered_user_not_found} | {:error, :unauthorized}
  )
end
