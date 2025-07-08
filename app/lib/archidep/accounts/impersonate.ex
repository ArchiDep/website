defmodule ArchiDep.Accounts.Impersonate do
  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserSession

  @spec impersonate(Authentication.t(), UUID.t()) ::
          {:ok, UserAccount.t()} | {:error, :user_account_not_found} | {:error, :unauthorized}
  def impersonate(auth, user_id) do
    with :ok <- validate_uuid(user_id, :user_account_not_found),
         {:ok, user_account} <- UserAccount.fetch_by_id(user_id),
         :ok <- authorize(auth, Policy, :accounts, :impersonate, user_account) do
      UserSession.impersonate(auth.session, user_account)
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
    with :ok <- authorize(auth, Policy, :accounts, :stop_impersonating, nil) do
      UserSession.stop_impersonating(auth.session)
      :ok
    else
      {:error, {:access_denied, :accounts, :stop_impersonating}} ->
        {:error, :unauthorized}
    end
  end
end
