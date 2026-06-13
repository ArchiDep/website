defmodule ArchiDep.Accounts.UseCases.Impersonate do
  @moduledoc """
  Use case for impersonating a user account, i.e. allowing an administrator to
  act as another user. This is typically used for support or debugging purposes.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.UserImpersonated
  alias ArchiDep.Accounts.Events.UserStoppedImpersonating
  alias ArchiDep.Accounts.Policy
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Clock

  @spec impersonate(Authentication.t(), UUID.t()) ::
          {:ok, UserAccount.t()} | {:error, :user_account_not_found} | {:error, :unauthorized}
  def impersonate(auth, user_id) do
    now = Clock.now()

    with :ok <- validate_uuid(user_id, :user_account_not_found),
         {:ok, user_account} <- UserAccount.fetch_by_id(user_id),
         :ok <- authorize(auth, Policy, :accounts, :impersonate, user_account) do
      {:ok, session} = UserSession.fetch_by_id(auth.session_id)
      {:ok, _result} = store_impersonation(session, user_account, auth, now)

      :telemetry.execute([:archidep, :accounts, :auth, :impersonate], %{}, %{
        principal_id: Authentication.principal_id(auth),
        impersonated_id: user_account.id
      })

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
    now = Clock.now()

    case authorize(auth, Policy, :accounts, :stop_impersonating, nil) do
      :ok ->
        {:ok, session} = UserSession.fetch_by_id(auth.session_id)
        {:ok, _result} = store_stop_impersonation(session, auth, now)

        :telemetry.execute([:archidep, :accounts, :auth, :stop_impersonating], %{}, %{
          principal_id: Authentication.principal_id(auth)
        })

        :ok

      {:error, {:access_denied, :accounts, :stop_impersonating}} ->
        {:error, :unauthorized}
    end
  end

  defp store_impersonation(session, user_account, auth, now) do
    %UserSession{user_account: impersonator} = session

    Multi.new()
    |> update(:user_session, UserSession.impersonate(session, user_account))
    |> insert(
      :stored_event,
      session
      |> UserImpersonated.new(user_account)
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(impersonator)
    )
    |> transaction()
  end

  defp store_stop_impersonation(session, auth, now) do
    %UserSession{user_account: user_account} = session

    Multi.new()
    |> update(:user_session, UserSession.stop_impersonating(session))
    |> insert(
      :stored_event,
      session
      |> UserStoppedImpersonating.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(user_account)
    )
    |> transaction()
  end
end
