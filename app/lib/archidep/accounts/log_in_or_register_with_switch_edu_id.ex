defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduId do
  @moduledoc """
  User account management use case for a user to log in, creating a valid
  authentication object that can be used for authorization in other use cases.
  """
  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId
  alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.ClientMetadata

  @root_users :archidep |> Application.compile_env!(:root_users) |> Keyword.fetch!(:switch_edu_id)

  @spec log_in_or_register_with_switch_edu_id(
          Types.switch_edu_id_data(),
          ClientMetadata.t()
        ) ::
          {:ok, Authentication.t()}
          | {:error, :unauthorized_switch_edu_id}
  def log_in_or_register_with_switch_edu_id(
        switch_edu_id_data,
        client_metadata
      ) do
    with {:ok, roles} <- authorize_switch_edu_id_account(switch_edu_id_data),
         {:ok, %{user_session: session}} <-
           log_in_or_register(switch_edu_id_data, roles, client_metadata) do
      {:ok, Authentication.for_user_session(session, client_metadata)}
    else
      error -> error
    end
  end

  defp authorize_switch_edu_id_account(switch_edu_id_data) do
    if Enum.member?(@root_users, switch_edu_id_data.email) ||
         Enum.member?(@root_users, switch_edu_id_data.swiss_edu_person_unique_id) do
      {:ok, [:root]}
    else
      {:error, :unauthorized_switch_edu_id}
    end
  end

  defp log_in_or_register(switch_edu_id_data, roles, client_metadata) do
    Multi.new()
    |> Multi.insert_or_update(
      :switch_edu_id,
      SwitchEduId.create_or_update(switch_edu_id_data)
    )
    |> Multi.run(
      :user_account_and_state,
      fn _repo, %{switch_edu_id: switch_edu_id} ->
        switch_edu_id |> UserAccount.fetch_or_create_for_switch_edu_id(roles) |> ok()
      end
    )
    |> Multi.insert_or_update(:user_account, fn %{user_account_and_state: {_state, changeset}} ->
      changeset
    end)
    |> Multi.insert(:user_session, fn %{user_account: user_account} ->
      UserSession.new_session(user_account, client_metadata)
    end)
    |> insert(:stored_event, fn
      %{
        switch_edu_id: switch_edu_id,
        user_account_and_state: {state, _changeset},
        user_account: user_account,
        user_session: session
      } ->
        case state do
          :new_account ->
            UserRegisteredWithSwitchEduId.new(switch_edu_id, user_account, session)
            |> new_event(client_metadata, occurred_at: session.created_at)
            |> add_to_stream(user_account)
            |> initiated_by(user_account)

          :existing_account ->
            UserLoggedInWithSwitchEduId.new(switch_edu_id, session, client_metadata)
            |> new_event(client_metadata, occurred_at: session.created_at)
            |> add_to_stream(user_account)
            |> initiated_by(user_account)
        end
    end)
    |> transaction()
  end
end
