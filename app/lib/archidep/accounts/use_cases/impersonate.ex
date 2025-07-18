defmodule ArchiDep.Accounts.UseCases.Impersonate do
  @moduledoc """
  Use case for impersonating a user account, i.e. allowing an administrator to
  act as another user. This is typically used for support or debugging purposes.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserSession

  @spec impersonate(Authentication.t(), UUID.t()) ::
          {:ok, UserAccount.t()} | {:error, :user_account_not_found} | {:error, :unauthorized}
  def impersonate(auth, user_id) do
    with :ok <- validate_uuid(user_id, :user_account_not_found),
         {:ok, user_account} <- UserAccount.fetch_by_id(user_id),
         :ok <- authorize(auth, Policy, :accounts, :impersonate, user_account) do
      {:ok, session} = UserSession.fetch_by_id(auth.session_id)
      UserSession.impersonate(session, user_account)
      {:ok, user_account}
    else
      {:error, :user_account_not_found} ->
        {:error, :user_account_not_found}

      {:error, {:access_denied, :accounts, :impersonate}} ->
        {:error, :unauthorized}
    end
  end

  @spec stop_impersonating(Authentication.t()) :: :ok | {:error, :unauthorized}
  def stop_impersonating(auth) do
    case authorize(auth, Policy, :accounts, :stop_impersonating, nil) do
      :ok ->
        {:ok, session} = UserSession.fetch_by_id(auth.session_id)
        UserSession.stop_impersonating(session)
        :ok

      {:error, {:access_denied, :accounts, :stop_impersonating}} ->
        {:error, :unauthorized}
    end
  end
end
