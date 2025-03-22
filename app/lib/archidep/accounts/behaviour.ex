defmodule ArchiDep.Accounts.Behaviour do
  @moduledoc """
  Specification of the user account management context.
  """

  use ArchiDep.Helpers.ContextHelpers, :behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [callback: 1]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Types
  alias ArchiDep.Authentication

  @doc """
  Logs in the user account with the specified Switch edu-ID, creating a new
  session. If no user account exists for that Switch edu-ID, a new user account
  is registered.
  """
  callback(
    log_in_or_register_with_switch_edu_id(
      data: Types.switch_edu_id_data(),
      meta: map
    ) ::
      {:ok, Authentication.t()}
      | {:error, :unauthorized_switch_edu_id}
  )

  @doc """
  Authenticates using the specified session token. The token must correspond to
  an active session.
  """
  callback(
    validate_session(token: String.t(), meta: map) ::
      {:ok, Authentication.t()} | {:error, :session_not_found}
  )

  @doc """
  Fetches the user account corresponding to the current authentication.
  """
  callback(user_account(auth: Authentication.t()) :: UserAccount.t())

  @doc """
  Logs out a user account.
  """
  callback(log_out(auth: Authentication.t()) :: :ok | {:error, :session_not_found})
end
