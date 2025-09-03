defmodule ArchiDep.Accounts.UseCases.LogInOrRegisterWithSwitchEduId do
  @moduledoc """
  User account management use case for a user to log in, creating a valid
  authentication object that can be used for authorization in other use cases.
  """

  use ArchiDep, :use_case

  import Ecto.Changeset
  alias ArchiDep.Accounts.Events.UserLoggedInWithSwitchEduId
  alias ArchiDep.Accounts.Events.UserRegisteredWithSwitchEduId
  alias ArchiDep.Accounts.PubSub
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Events.Store.StoredEvent

  @spec log_in_or_register_with_switch_edu_id(
          Types.switch_edu_id_login_data(),
          ClientMetadata.t()
        ) ::
          {:ok, Authentication.t()}
          | {:error, :unauthorized_switch_edu_id}
  def log_in_or_register_with_switch_edu_id(
        switch_edu_id_data,
        client_metadata
      ) do
    case log_in_or_register(switch_edu_id_data, client_metadata) do
      {:ok,
       %{
         user_account: user_account,
         user_session: session,
         linked_preregistered_user: preregistered_user
       }} ->
        if preregistered_user != nil do
          :ok = PubSub.publish_preregistered_user_updated(preregistered_user)
        end

        enriched_session = %UserSession{
          session
          | user_account: user_account,
            impersonated_user_account: nil
        }

        {:ok, UserSession.authentication(enriched_session)}

      {:error, _operation, :unauthorized_switch_edu_id, _changes} ->
        {:error, :unauthorized_switch_edu_id}
    end
  end

  defp log_in_or_register(switch_edu_id_data, client_metadata) do
    Multi.new()
    # Create or update the Switch edu-ID identity. It might or might not already
    # exist and be linked to a user account.
    |> Multi.insert_or_update(
      :switch_edu_id,
      SwitchEduId.create_or_update(switch_edu_id_data)
    )
    # Determine whether the user account already exists or needs to be
    # created...
    |> Multi.run(
      :user_account_and_state,
      fn _repo, %{switch_edu_id: switch_edu_id} ->
        case UserAccount.fetch_for_switch_edu_id(switch_edu_id) do
          nil ->
            new_user_account(switch_edu_id, switch_edu_id_data)

          user_account ->
            existing_user_account(switch_edu_id_data, user_account)
        end
      end
    )
    # Create or apply any updates to the user account.
    |> Multi.insert_or_update(:user_account, fn %{
                                                  user_account_and_state:
                                                    {_state, changeset, _preregistered_user}
                                                } ->
      changeset
    end)
    # Link the user account and preregistered user together if necessary.
    |> Multi.merge(fn %{
                        user_account_and_state: user_account_and_state,
                        user_account: user_account
                      } ->
      case user_account_and_state do
        {:new_student, _user_account, %PreregisteredUser{} = preregistered_user} ->
          Multi.update(
            Multi.new(),
            :linked_preregistered_user,
            PreregisteredUser.link_to_user_account(
              preregistered_user,
              user_account,
              DateTime.utc_now()
            )
          )

        {:existing_student, _user_account, preregistered_user} ->
          Multi.new()
          |> Multi.update(
            :linked_preregistered_user,
            PreregisteredUser.link_to_user_account(
              preregistered_user,
              user_account,
              DateTime.utc_now()
            )
          )
          |> Multi.update(
            :linked_user_account,
            UserAccount.relink_to_preregistered_user(user_account, preregistered_user)
          )

        _otherwise ->
          Multi.new()
          |> Multi.put(:linked_preregistered_user, nil)
          |> Multi.put(:linked_user_account, nil)
      end
    end)
    # Create a new session for the user account which is logging in.
    |> Multi.insert(:user_session, &UserSession.new_session(&1.user_account, client_metadata))
    # Store either a registration or a login event as appropriate.
    |> insert(:stored_event, fn
      %{
        switch_edu_id: switch_edu_id,
        user_account_and_state: {state, _changeset, _preregistered_user},
        linked_preregistered_user: preregistered_user,
        user_session: session
      } ->
        case state do
          s when s in [:new_root, :new_student] ->
            user_registered_with_switch_edu_id(
              switch_edu_id,
              session,
              preregistered_user
            )

          s when s in [:existing_account, :existing_student] ->
            user_logged_in_with_switch_edu_id(switch_edu_id, session, client_metadata)
        end
    end)
    |> transaction()
  end

  defp new_user_account(switch_edu_id, data) do
    # If the user account does not exist but one of the emails of the Switch
    # edu-ID account has been configured as a root user, create a new root user
    # account.
    if configured_root_user?(data) do
      {:ok, {:new_root, UserAccount.new_root_switch_edu_id_account(switch_edu_id), nil}}
    else
      # Otherwise check whether there is a preregistered user for that
      # email...
      case PreregisteredUser.list_available_preregistered_users_for_emails(
             data.emails,
             nil,
             DateTime.utc_now()
           ) do
        # If there is exactly one active preregistered user with a
        # matching email that is not yet linked to a user account,
        # create a new student user account.
        [exactly_one_preregistered_user] ->
          {:ok,
           {
             :new_student,
             # and one for new student accounts. Directly link the
             # account to the student in the latter.
             UserAccount.new_preregistered_switch_edu_id_account(
               switch_edu_id,
               exactly_one_preregistered_user
             ),
             exactly_one_preregistered_user
           }}

        # If there are no preregistered users or more than one matches,
        # deny access.
        _zero_or_multiple_preregistered_users ->
          {:error, :unauthorized_switch_edu_id}
      end
    end
  end

  defp existing_user_account(switch_edu_id_data, user_account) do
    # If the user account already exists, check whether it is still active (it
    # might be linked to a class from the previous year, or it or its linked
    # preregistered user might have been deactivated).
    #
    # If the user account is active, log it in.
    if UserAccount.active?(user_account, DateTime.utc_now()) do
      {:ok, {:existing_account, change(user_account), nil}}
    else
      # Otherwise, check whether there is a new preregistered user for
      # the same email (e.g. a student might be repeating a year, in
      # which case a new preregistered user will have been created in
      # a new class)...
      case PreregisteredUser.list_available_preregistered_users_for_emails(
             switch_edu_id_data.emails,
             user_account.id,
             DateTime.utc_now()
           ) do
        # If there is exactly one active preregistered user with a
        # matching email that is not yet linked to a user account,
        # link the user account to it.
        [exactly_one_preregistered_user] ->
          {:ok, {:existing_student, change(user_account), exactly_one_preregistered_user}}

        # If there are no preregistered users or more than one matches,
        # deny access.
        _zero_or_multiple_preregistered_users ->
          {:error, :unauthorized_switch_edu_id}
      end
    end
  end

  defp configured_root_user?(%{
         swiss_edu_person_unique_id: swiss_edu_person_unique_id,
         emails: emails
       }) do
    known_root_users = root_users()

    Enum.member?(known_root_users, swiss_edu_person_unique_id) ||
      Enum.any?(emails, &Enum.member?(known_root_users, &1))
  end

  defp root_users,
    do:
      :archidep
      |> Application.fetch_env!(:auth)
      |> Keyword.fetch!(:root_users)
      |> Keyword.fetch!(:switch_edu_id)

  defp user_registered_with_switch_edu_id(
         switch_edu_id,
         session,
         preregistered_user
       ),
       do:
         switch_edu_id
         |> UserRegisteredWithSwitchEduId.new(
           session,
           preregistered_user
         )
         |> new_event(%{}, occurred_at: session.user_account.created_at)
         |> add_to_stream(session.user_account)
         |> StoredEvent.initiated_by(UserAccount.event_stream(session.user_account))

  defp user_logged_in_with_switch_edu_id(
         switch_edu_id,
         session,
         client_metadata
       ),
       do:
         switch_edu_id
         |> UserLoggedInWithSwitchEduId.new(session, client_metadata)
         |> new_event(%{}, occurred_at: session.created_at)
         |> add_to_stream(session.user_account)
         |> StoredEvent.initiated_by(UserAccount.event_stream(session.user_account))
end
