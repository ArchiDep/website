defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduIdTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.Factory

  @root_user_email "root@archidep.ch"

  setup :verify_on_exit!

  setup_all do
    %{
      log_in_or_register_with_switch_edu_id:
        protect({Context, :log_in_or_register_with_switch_edu_id, 2}, Behaviour)
    }
  end

  test "register a root user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_data =
      AccountsFactory.build(:switch_edu_id_data, email: @root_user_email, first_name: nil)

    client_metadata = Factory.build(:client_metadata, ip_address: nil, user_agent: nil)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_data,
               client_metadata
             )

    assert %Authentication{
             principal_id: user_account_id,
             session_id: session_id,
             session_token: session_token
           } = auth

    assert auth == %Authentication{
             principal_id: user_account_id,
             username: "root",
             roles: [:root],
             session_id: session_id,
             session_token: session_token,
             impersonated_id: nil
           }

    assert [
             %StoredEvent{
               __meta__: meta,
               id: event_id,
               data: %{"switch_edu_id" => switch_edu_id_id},
               occurred_at: occurred_at
             } = registered_event
           ] = Repo.all(from e in StoredEvent, order_by: [asc: e.occurred_at])

    assert registered_event == %StoredEvent{
             __meta__: meta,
             id: event_id,
             stream: "user-accounts:#{user_account_id}",
             version: 1,
             type: "archidep/accounts/user-registered-with-switch-edu-id",
             data: %{
               "switch_edu_id" => switch_edu_id_id,
               "email" => @root_user_email,
               "first_name" => nil,
               "last_name" => switch_edu_id_data[:last_name],
               "swiss_edu_person_unique_id" => switch_edu_id_data[:swiss_edu_person_unique_id],
               "user_account_id" => user_account_id,
               "username" => "root",
               "session_id" => session_id,
               "client_ip_address" => nil,
               "client_user_agent" => nil,
               "preregistered_user_id" => nil
             },
             meta: %{},
             initiator: "user-accounts:#{user_account_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: occurred_at,
             entity: nil
           }

    assert [
             %UserSession{
               __meta__: session_meta,
               user_account: %UserAccount{
                 __meta__: user_account_meta,
                 switch_edu_id: %SwitchEduId{
                   __meta__: switch_edu_id_meta,
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
             __meta__: session_meta,
             id: session_id,
             token: session_token,
             created_at: session_created_at,
             user_account: %UserAccount{
               __meta__: user_account_meta,
               id: user_account_id,
               username: "root",
               roles: [:root],
               active: true,
               switch_edu_id: %SwitchEduId{
                 __meta__: switch_edu_id_meta,
                 id: switch_edu_id_id,
                 email: @root_user_email,
                 first_name: nil,
                 last_name: switch_edu_id_data[:last_name],
                 swiss_edu_person_unique_id: switch_edu_id_data[:swiss_edu_person_unique_id],
                 version: 1,
                 created_at: switch_edu_id_created_at,
                 updated_at: switch_edu_id_created_at,
                 used_at: switch_edu_id_created_at
               },
               switch_edu_id_id: switch_edu_id_id,
               preregistered_user: nil,
               preregistered_user_id: nil,
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
