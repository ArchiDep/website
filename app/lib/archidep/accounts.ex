defmodule ArchiDep.Accounts do
  @moduledoc """
  Accounts context, which concerns everything related to user accounts,
  including authentication, user sessions, and account management.
  """

  @behaviour ArchiDep.Accounts.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @doc """
  Logs in the user account with the specified Switch edu-ID, creating a new
  session. If no user account exists for that Switch edu-ID, a new user account
  is registered.
  """
  @spec log_in_or_register_with_switch_edu_id(Types.switch_edu_id_login_data(), map) ::
          {:ok, Authentication.t()}
          | {:error, :unauthorized_switch_edu_id}
  defdelegate log_in_or_register_with_switch_edu_id(data, meta), to: @implementation

  @doc """
  Logs in a user account with the specified login link token, creating a new
  session. If that login linked corresponds to a preregistered user and no user
  account yet exists for that user, a new user account is registered.
  """
  @spec log_in_or_register_with_link(binary(), map) ::
          {:ok, Authentication.t()} | {:error, :invalid_link}
  defdelegate log_in_or_register_with_link(token, meta), to: @implementation

  @doc """
  Authenticates using the specified session token. The token must correspond to
  an active session.
  """
  @spec validate_session_token(String.t(), map) ::
          {:ok, Authentication.t()} | {:error, :session_not_found}
  defdelegate validate_session_token(token, meta), to: @implementation

  @doc """
  Authenticates using the specified session ID. The ID must be that of an active
  session.
  """
  @spec validate_session_id(UUID.t(), map) ::
          {:ok, Authentication.t()} | {:error, :session_not_found}
  defdelegate validate_session_id(id, meta), to: @implementation

  @doc """
  Returns the list of active sessions for the currently authenticated user.
  """
  @spec fetch_active_sessions(Authentication.t()) :: list(UserSession.t())
  defdelegate fetch_active_sessions(auth), to: @implementation

  @doc """
  Impersonates the specified user account. As long as this is active, that
  session will behave as if the specified user account is the logged-in user.
  """
  @spec impersonate(Authentication.t(), UUID.t()) ::
          {:ok, UserAccount.t()} | {:error, :user_account_not_found} | {:error, :unauthorized}
  defdelegate impersonate(auth, user_id), to: @implementation

  @doc """
  Stops impersonating a user account, returning to the original session.
  """
  @spec stop_impersonating(Authentication.t()) :: :ok | {:error, :unauthorized}
  defdelegate stop_impersonating(auth), to: @implementation

  @doc """
  Deletes the specified session.
  """
  @spec delete_session(Authentication.t(), String.t()) ::
          {:ok, UserSession.t()} | {:error, :session_not_found}
  defdelegate delete_session(auth, id), to: @implementation

  @doc """
  Fetches the user account corresponding to the current authentication.
  """
  @spec user_account(Authentication.t()) :: UserAccount.t()
  defdelegate user_account(auth), to: @implementation

  @doc """
  Logs out a user account.
  """
  @spec log_out(Authentication.t()) :: :ok | {:error, :session_not_found}
  defdelegate log_out(auth), to: @implementation

  @doc """
  Creates a new login link for the specified preregistered user.
  """
  @spec create_login_link_for_preregistered_user(Authentication.t(), UUID.t()) ::
          {:ok, LoginLink.t()} | {:error, :preregistered_user_not_found} | {:error, :unauthorized}
  defdelegate create_login_link_for_preregistered_user(auth, preregistered_user_id),
    to: @implementation
end
