defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduId do
  @moduledoc """
  User account management use case for a user to log in, creating a valid
  authentication object that can be used for authorization in other use cases.
  """
  use ArchiDep, :use_case

  alias ArchiDep.Accounts.Events.SwitchEduIdUserLoggedIn
  alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types

  @root_users :archidep |> Application.compile_env!(:root_users) |> Keyword.fetch!(:switch_edu_id)

  @spec log_in_or_register_with_switch_edu_id(
          Types.switch_edu_id_data(),
          map
        ) ::
          {:ok, Authentication.t()}
          | {:error, :unauthorized_switch_edu_id}
  def log_in_or_register_with_switch_edu_id(
        switch_edu_id_data,
        meta
      ) do
    with {:ok, roles} <- authorize_switch_edu_id_account(switch_edu_id_data),
         {:ok, %{switch_edu_id: switch_edu_id}} <-
           log_in_or_register(switch_edu_id_data, roles, meta) do
      IO.puts("@@@ OK #{inspect(switch_edu_id)}")
      {:error, :unauthorized_switch_edu_id}
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

  defp log_in_or_register(switch_edu_id_data, roles, meta) do
    Multi.new()
    |> Multi.insert_or_update(
      :switch_edu_id,
      SwitchEduId.create_or_update(switch_edu_id_data)
    )
    |> Multi.insert_or_update(
      :user_account,
      fn %{switch_edu_id: switch_edu_id} ->
        UserAccount.fetch_or_create_for_switch_edu_id(switch_edu_id, roles)
      end
    )
    |> Multi.insert(:session, fn %{user_account: user_account} ->
      UserSession.new_session(user_account, EventMetadata.extract(meta))
    end)
    # |> insert(:stored_event, fn %{user_session: session} ->
    #   session
    #   |> UserLoggedIn.new()
    #   |> new_event(metadata, occurred_at: session.created_at)
    #   |> add_to_stream(user_account)
    #   |> initiated_by(user_account)
    # end)
    |> transaction()
  end
end
