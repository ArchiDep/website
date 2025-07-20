defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduIdTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  @root_user_email "root@archidep.ch"

  setup :verify_on_exit!

  setup_all do
    %{
      log_in_or_register_with_switch_edu_id:
        protect({Context, :log_in_or_register_with_switch_edu_id, 2}, Behaviour)
    }
  end

  test "register a new root user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_data =
      AccountsFactory.build(:switch_edu_id_data, email: @root_user_email, first_name: nil)

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_data,
               metadata
             )

    auth
    |> assert_auth("root", :root)
    |> assert_registered_event(metadata, "root", @root_user_email, switch_edu_id_data)
    |> assert_user_session(auth, "root", @root_user_email, :root)
  end

  test "register a new student user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    class = CourseFactory.insert(:class, active: true, start_date: nil, end_date: nil)

    student =
      CourseFactory.insert(:student,
        email: "bob@archidep.ch",
        active: true,
        class: class,
        user: nil
      )

    switch_edu_id_data =
      AccountsFactory.build(:switch_edu_id_data, email: student.email, first_name: nil)

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_data,
               metadata
             )

    auth
    |> assert_auth("bob", :student)
    |> assert_registered_event(metadata, "bob", "bob@archidep.ch", switch_edu_id_data, student)
    |> assert_user_session(auth, "bob", "bob@archidep.ch", :student, student)
  end

  test "an unknown user cannot register even if their Switch edu-ID account is valid", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_data =
      AccountsFactory.build(:switch_edu_id_data)

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_data,
               metadata
             )

    assert [] = Repo.all(SwitchEduId)
    assert [] = Repo.all(UserAccount)
    assert [] = Repo.all(UserSession)
  end

  test "an unknown user cannot register even if their Switch edu-ID account is known", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id =
      AccountsFactory.insert(:switch_edu_id)

    switch_edu_id_data =
      AccountsFactory.build(:switch_edu_id_data,
        email: switch_edu_id.email,
        swiss_edu_person_unique_id: switch_edu_id.swiss_edu_person_unique_id
      )

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_data,
               metadata
             )

    assert [^switch_edu_id] = Repo.all(SwitchEduId)
    assert [] = Repo.all(UserAccount)
    assert [] = Repo.all(UserSession)
  end

  defp assert_auth(auth, username, role) do
    assert %Authentication{
             principal_id: user_account_id,
             session_id: session_id,
             session_token: session_token
           } = auth

    assert auth == %Authentication{
             principal_id: user_account_id,
             username: username,
             roles: [role],
             session_id: session_id,
             session_token: session_token,
             impersonated_id: nil
           }

    auth
  end

  defp assert_registered_event(
         %Authentication{principal_id: user_account_id, session_id: session_id},
         client_metadata,
         username,
         email,
         switch_edu_id_data,
         student \\ nil
       ) do
    assert [
             %StoredEvent{
               id: event_id,
               data: %{"switch_edu_id" => switch_edu_id_id},
               occurred_at: occurred_at
             } = registered_event
           ] = Repo.all(from e in StoredEvent, order_by: [asc: e.occurred_at])

    assert registered_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "user-accounts:#{user_account_id}",
             version: 1,
             type: "archidep/accounts/user-registered-with-switch-edu-id",
             data: %{
               "switch_edu_id" => switch_edu_id_id,
               "email" => email,
               "first_name" => nil,
               "last_name" => switch_edu_id_data[:last_name],
               "swiss_edu_person_unique_id" => switch_edu_id_data[:swiss_edu_person_unique_id],
               "user_account_id" => user_account_id,
               "username" => username,
               "session_id" => session_id,
               "client_ip_address" =>
                 client_metadata.ip_address
                 |> truthy_then(&:inet.ntoa/1)
                 |> truthy_then(&List.to_string/1),
               "client_user_agent" => client_metadata.user_agent,
               "preregistered_user_id" => student && student.id
             },
             meta: %{},
             initiator: "user-accounts:#{user_account_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: occurred_at,
             entity: nil
           }

    registered_event
  end

  defp assert_user_session(
         %StoredEvent{
           data: %{
             "switch_edu_id" => switch_edu_id_id,
             "first_name" => first_name,
             "last_name" => last_name,
             "swiss_edu_person_unique_id" => swiss_edu_person_unique_id,
             "client_ip_address" => client_ip_address,
             "client_user_agent" => client_user_agent
           },
           occurred_at: occurred_at
         },
         %Authentication{
           principal_id: user_account_id,
           session_id: session_id,
           session_token: session_token
         },
         username,
         email,
         role,
         student \\ nil
       ) do
    assert [
             %UserSession{
               user_account: %UserAccount{
                 switch_edu_id: %SwitchEduId{
                   created_at: switch_edu_id_created_at
                 }
               },
               created_at: session_created_at
             } = user_session
           ] =
             Repo.all(
               from us in UserSession,
                 join: ua in assoc(us, :user_account),
                 left_join: pu in assoc(ua, :preregistered_user),
                 join: sei in assoc(ua, :switch_edu_id),
                 left_join: iua in assoc(us, :impersonated_user_account),
                 preload: [
                   user_account: {ua, preregistered_user: pu, switch_edu_id: sei},
                   impersonated_user_account: iua
                 ]
             )

    assert user_session == %UserSession{
             __meta__: loaded(UserSession, "user_sessions"),
             id: session_id,
             token: session_token,
             created_at: session_created_at,
             client_ip_address: client_ip_address,
             client_user_agent: client_user_agent,
             user_account: %UserAccount{
               __meta__: loaded(UserAccount, "user_accounts"),
               id: user_account_id,
               username: username,
               roles: [role],
               active: true,
               switch_edu_id: %SwitchEduId{
                 __meta__: loaded(SwitchEduId, "switch_edu_ids"),
                 id: switch_edu_id_id,
                 email: email,
                 first_name: first_name,
                 last_name: last_name,
                 swiss_edu_person_unique_id: swiss_edu_person_unique_id,
                 version: 1,
                 created_at: switch_edu_id_created_at,
                 updated_at: switch_edu_id_created_at,
                 used_at: switch_edu_id_created_at
               },
               switch_edu_id_id: switch_edu_id_id,
               preregistered_user:
                 if student do
                   [preregistered_user_updated_at] =
                     Repo.one(
                       from pu in PreregisteredUser,
                         select: [pu.updated_at],
                         where: pu.id == ^student.id
                     )

                   %PreregisteredUser{
                     __meta__: loaded(PreregisteredUser, "students"),
                     id: student.id,
                     email: student.email,
                     active: true,
                     group: not_loaded(:group, PreregisteredUser),
                     group_id: student.class_id,
                     user_account: not_loaded(:user_account, PreregisteredUser),
                     user_account_id: user_account_id,
                     version: student.version + 1,
                     updated_at: preregistered_user_updated_at
                   }
                 else
                   nil
                 end,
               preregistered_user_id: student && student.id,
               version: 1,
               created_at: occurred_at,
               updated_at: occurred_at
             },
             user_account_id: user_account_id,
             impersonated_user_account: nil,
             impersonated_user_account_id: nil
           }
  end
end
