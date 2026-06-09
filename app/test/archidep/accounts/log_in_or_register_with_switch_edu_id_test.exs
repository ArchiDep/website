defmodule ArchiDep.Accounts.LogInOrRegisterWithSwitchEduIdTest do
  use ArchiDep.Support.DataCase, async: true

  import Ecto.Query, only: [from: 2]
  import Hammox
  import ArchiDep.Support.TelemetryTestHelpers
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.PubSub
  alias ArchiDep.Accounts.Schemas.Identity.SwitchEduId
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.Clock
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  @root_user_email "root@archidep.ch"
  @root_user_swiss_edu_person_unique_id "root-by-unique-id"

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see docs/testing.md).
  @now ~U[2024-03-15 10:30:00.000000Z]
  @session_validity_in_seconds 30 * 24 * 60 * 60

  @login_telemetry_event [:archidep, :accounts, :auth, :login]

  setup :verify_on_exit!

  setup context do
    stub(Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @login_telemetry_event)
    :ok
  end

  setup_all do
    %{
      log_in_or_register_with_switch_edu_id:
        protect({Context, :log_in_or_register_with_switch_edu_id, 2}, Behaviour)
    }
  end

  test "register a new root user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        emails: [@root_user_email],
        first_name: nil,
        swiss_edu_person_unique_id: "foobar"
      )

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth("root@archidep.ch", true)
    |> assert_login_telemetry()
    |> assert_registered_event(metadata, "root@archidep.ch", switch_edu_id_login_data)
    |> assert_user_session_for_new_user(auth, "root@archidep.ch", true)
  end

  test "register a new root user account matched by Switch edu-ID unique identifier", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        emails: ["not-a-root@archidep.ch"],
        first_name: nil,
        swiss_edu_person_unique_id: @root_user_swiss_edu_person_unique_id
      )

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(@root_user_swiss_edu_person_unique_id, true)
    |> assert_login_telemetry()
    |> assert_registered_event(
      metadata,
      @root_user_swiss_edu_person_unique_id,
      switch_edu_id_login_data
    )
    |> assert_user_session_for_new_user(auth, @root_user_swiss_edu_person_unique_id, true)
  end

  test "register a new student user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)

    student =
      CourseFactory.insert(:student,
        email: "bob@archidep.ch",
        active: true,
        class: class,
        user: nil,
        now: @now
      )

    subscribe_to_preregistered_user(student)

    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        emails: [student.email],
        first_name: nil,
        swiss_edu_person_unique_id: "bob"
      )

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(nil, false)
    |> assert_login_telemetry()
    |> assert_registered_event(
      metadata,
      nil,
      switch_edu_id_login_data,
      student
    )
    |> assert_user_session_for_new_user(auth, nil, false, student)

    assert_preregistered_user_broadcast(student)
  end

  test "an unknown user cannot register even if their Switch edu-ID account is valid", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data)

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    assert [] = Repo.all(SwitchEduId)
    assert [] = Repo.all(UserAccount)
    assert [] = Repo.all(UserSession)
    assert_no_stored_events!()
    refute_login_telemetry()
  end

  test "an unknown user cannot register even if their Switch edu-ID account is in the database",
       %{
         log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
       } do
    switch_edu_id =
      AccountsFactory.insert(:switch_edu_id, now: @now)

    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        swiss_edu_person_unique_id: switch_edu_id.swiss_edu_person_unique_id
      )

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    assert [^switch_edu_id] = Repo.all(SwitchEduId)
    assert [] = Repo.all(UserAccount)
    assert [] = Repo.all(UserSession)
    assert_no_stored_events!()
    refute_login_telemetry()
  end

  test "an unknown user cannot register when their email matches several preregistered users", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    email = "duplicate@archidep.ch"

    class_one = CourseFactory.insert(:class, active: true, now: @now)

    student_one =
      CourseFactory.insert(:student,
        email: email,
        active: true,
        class: class_one,
        user: nil,
        now: @now
      )

    class_two = CourseFactory.insert(:class, active: true, now: @now)

    student_two =
      CourseFactory.insert(:student,
        email: email,
        active: true,
        class: class_two,
        user: nil,
        now: @now
      )

    subscribe_to_preregistered_user(student_one)
    subscribe_to_preregistered_user(student_two)

    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data, emails: [email])

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    assert [] = Repo.all(SwitchEduId)
    assert [] = Repo.all(UserAccount)
    assert [] = Repo.all(UserSession)
    assert_no_stored_events!()
    refute_login_telemetry()
    refute_preregistered_user_broadcast()
  end

  test "log in an existing root user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    {switch_edu_id, switch_edu_id_login_data} = insert_existing_switch_edu_id([@root_user_email])

    user_account =
      AccountsFactory.insert(:user_account,
        username: @root_user_email,
        root: true,
        active: true,
        switch_edu_id: switch_edu_id,
        now: @now
      )

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(@root_user_email, true)
    |> assert_login_telemetry()
    |> assert_logged_in_event(metadata, user_account, switch_edu_id_login_data, false)
    |> assert_user_session_for_existing_user(auth, user_account, switch_edu_id, true, false)
  end

  test "log in an existing student user account with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    subscribe_to_preregistered_user(student)

    {switch_edu_id, switch_edu_id_login_data} = insert_existing_switch_edu_id([student.email])

    user_account =
      AccountsFactory.insert(:user_account,
        root: false,
        active: true,
        switch_edu_id: switch_edu_id,
        preregistered_user_id: student.id,
        now: @now
      )

    link_student_to_user_account(student, user_account)

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(user_account.username, false)
    |> assert_login_telemetry()
    |> assert_logged_in_event(metadata, user_account, switch_edu_id_login_data, false, student)
    |> assert_user_session_for_existing_user(
      auth,
      user_account,
      switch_edu_id,
      false,
      false,
      student
    )

    refute_preregistered_user_broadcast()
  end

  test "log in an existing student user account with Switch edu-ID when it has previous logged in with a link",
       %{
         log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
       } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    subscribe_to_preregistered_user(student)

    switch_edu_id_login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        emails: [student.email],
        swiss_edu_person_unique_id: "foobar"
      )

    user_account =
      AccountsFactory.insert(:user_account,
        root: false,
        active: true,
        switch_edu_id: nil,
        preregistered_user_id: student.id,
        now: @now
      )

    link_student_to_user_account(student, user_account)

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(user_account.username, false)
    |> assert_login_telemetry()
    |> assert_logged_in_event(metadata, user_account, switch_edu_id_login_data, true, student)
    |> assert_user_session_for_existing_user(
      auth,
      user_account,
      switch_edu_id_login_data,
      false,
      :user_account,
      student
    )

    assert_preregistered_user_broadcast(student)
  end

  test "log in an existing inactive student user account to a new student with Switch edu-ID", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    subscribe_to_preregistered_user(student)

    old_class = CourseFactory.insert(:class, active: false)

    old_student =
      CourseFactory.insert(:student,
        email: student.email,
        active: true,
        class: old_class,
        user: nil
      )

    {switch_edu_id, switch_edu_id_login_data} = insert_existing_switch_edu_id([student.email])

    user_account =
      AccountsFactory.insert(:user_account,
        root: false,
        active: true,
        switch_edu_id: switch_edu_id,
        preregistered_user_id: old_student.id,
        now: @now
      )

    link_student_to_user_account(old_student, user_account)

    metadata = Factory.build(:client_metadata)

    assert {:ok, auth} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    auth
    |> assert_auth(user_account.username, false)
    |> assert_login_telemetry()
    |> assert_logged_in_event(
      metadata,
      user_account,
      switch_edu_id_login_data,
      true,
      student
    )
    |> assert_user_session_for_existing_user(
      auth,
      user_account,
      switch_edu_id,
      false,
      true,
      student
    )

    assert_preregistered_user_broadcast(student)
  end

  test "an existing inactive user account cannot log in without a new preregistration", %{
    log_in_or_register_with_switch_edu_id: log_in_or_register_with_switch_edu_id
  } do
    old_class = CourseFactory.insert(:class, active: false)
    old_student = CourseFactory.insert(:student, active: true, class: old_class, user: nil)

    subscribe_to_preregistered_user(old_student)

    {switch_edu_id, switch_edu_id_login_data} = insert_existing_switch_edu_id([old_student.email])

    user_account =
      AccountsFactory.insert(:user_account,
        root: false,
        active: true,
        switch_edu_id: switch_edu_id,
        preregistered_user_id: old_student.id,
        now: @now
      )

    link_student_to_user_account(old_student, user_account)

    metadata = Factory.build(:client_metadata)

    assert {:error, :unauthorized_switch_edu_id} =
             log_in_or_register_with_switch_edu_id.(
               switch_edu_id_login_data,
               metadata
             )

    # The Switch edu-ID and user account are left untouched (the transaction
    # rolled back, so used-at, version and updated-at were not bumped) and no
    # session, event, telemetry or broadcast was produced.
    assert [^switch_edu_id] = Repo.all(SwitchEduId)

    assert Repo.all(UserAccount) == [
             %{
               user_account
               | switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
                 preregistered_user: not_loaded(:preregistered_user, UserAccount)
             }
           ]

    assert [] = Repo.all(UserSession)
    assert_no_stored_events!()
    refute_login_telemetry()
    refute_preregistered_user_broadcast()
  end

  defp assert_auth(auth, username, root) do
    assert %Authentication{
             principal_id: user_account_id,
             session_id: session_id,
             session_token: session_token
           } = auth

    assert auth == %Authentication{
             principal_id: user_account_id,
             username: username,
             root: root,
             session_id: session_id,
             session_token: session_token,
             session_expires_at: DateTime.add(@now, @session_validity_in_seconds, :second),
             impersonated_id: nil
           }

    auth
  end

  defp assert_login_telemetry(%Authentication{principal_id: principal_id} = auth) do
    assert assert_telemetry_event!(@login_telemetry_event) == %{
             measurements: %{},
             metadata: %{method: :switch_edu_id, principal_id: principal_id},
             config: nil
           }

    auth
  end

  defp refute_login_telemetry do
    refute_received {:telemetry_event, @login_telemetry_event, _data}
  end

  defp subscribe_to_preregistered_user(%{id: id, class_id: class_id}) do
    :ok = PubSub.subscribe_preregistered_user(id)
    :ok = PubSub.subscribe_user_group_preregistered_users(class_id)
  end

  defp assert_preregistered_user_broadcast(%{id: id}) do
    # The use case broadcasts the updated preregistered user on two topics (the
    # preregistered user itself and its user group), so two messages are
    # expected, and no more.
    #
    # TODO DDD: assert the full payload by equality once the DDD refactoring
    # stabilizes the broadcast shape. For now this is intentionally partial
    # (message tag + id only) — see docs/testing.md.
    assert_receive {:preregistered_user_updated, %PreregisteredUser{id: ^id}}
    assert_receive {:preregistered_user_updated, %PreregisteredUser{id: ^id}}
    refute_received {:preregistered_user_updated, _payload}
  end

  defp refute_preregistered_user_broadcast do
    refute_received {:preregistered_user_updated, _payload}
  end

  # Inserts a Switch edu-ID identity and builds login data that matches it: the
  # same unique identifier (so the use case finds and updates the existing
  # identity rather than creating a new one) and the same name (so logging in
  # does not touch its `updated_at` — see
  # assert_user_session_for_existing_user).
  defp insert_existing_switch_edu_id(emails) do
    switch_edu_id =
      AccountsFactory.insert(:switch_edu_id,
        swiss_edu_person_unique_id: "foobar",
        first_name: "John",
        last_name: "Doe",
        now: @now
      )

    login_data =
      AccountsFactory.build(:switch_edu_id_login_data,
        emails: emails,
        first_name: "John",
        last_name: "Doe",
        swiss_edu_person_unique_id: "foobar"
      )

    {switch_edu_id, login_data}
  end

  defp link_student_to_user_account(%{id: student_id}, %UserAccount{id: user_account_id}) do
    {1, nil} =
      Repo.update_all(from(s in Student, where: s.id == ^student_id),
        set: [user_id: user_account_id]
      )

    :ok
  end

  defp assert_registered_event(
         %Authentication{principal_id: user_account_id, session_id: session_id},
         client_metadata,
         username,
         switch_edu_id_login_data,
         student \\ nil
       ) do
    assert [
             %StoredEvent{
               id: event_id,
               data: %{"switch_edu_id" => %{"id" => switch_edu_id_id}}
             } = registered_event
           ] = fetch_new_stored_events()

    assert registered_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{user_account_id}",
             version: 1,
             type: "archidep/accounts/user-registered-with-switch-edu-id",
             data: %{
               "switch_edu_id" => %{
                 "id" => switch_edu_id_id,
                 "first_name" => nil,
                 "last_name" => switch_edu_id_login_data[:last_name],
                 "swiss_edu_person_unique_id" =>
                   switch_edu_id_login_data[:swiss_edu_person_unique_id]
               },
               "user_account" => %{
                 "id" => user_account_id,
                 "username" => username,
                 "root" => student == nil
               },
               "session_id" => session_id,
               "client_ip_address" =>
                 client_metadata.ip_address
                 |> truthy_then(&:inet.ntoa/1)
                 |> truthy_then(&List.to_string/1),
               "client_user_agent" => client_metadata.user_agent,
               "preregistered_user" =>
                 if student do
                   %{
                     "id" => student.id,
                     "name" => student.name,
                     "email" => student.email
                   }
                 else
                   nil
                 end
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{user_account_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    registered_event
  end

  defp assert_logged_in_event(
         %Authentication{principal_id: user_account_id, session_id: session_id},
         client_metadata,
         %UserAccount{id: user_account_id} = user_account,
         switch_edu_id_login_data,
         updated,
         student \\ nil
       ) do
    assert [
             %StoredEvent{
               id: event_id,
               data: %{"switch_edu_id" => %{"id" => switch_edu_id_id}}
             } = logged_in_event
           ] = fetch_new_stored_events()

    assert logged_in_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{user_account_id}",
             version:
               if updated do
                 user_account.version + 1
               else
                 user_account.version
               end,
             type: "archidep/accounts/user-logged-in-with-switch-edu-id",
             data: %{
               "switch_edu_id" => %{
                 "id" => switch_edu_id_id,
                 "first_name" => switch_edu_id_login_data[:first_name],
                 "last_name" => switch_edu_id_login_data[:last_name],
                 "swiss_edu_person_unique_id" =>
                   switch_edu_id_login_data[:swiss_edu_person_unique_id]
               },
               "user_account" => %{
                 "id" => user_account_id,
                 "username" => user_account.username,
                 "root" => student == nil
               },
               "session_id" => session_id,
               "client_ip_address" =>
                 client_metadata.ip_address
                 |> truthy_then(&:inet.ntoa/1)
                 |> truthy_then(&List.to_string/1),
               "client_user_agent" => client_metadata.user_agent,
               "preregistered_user" =>
                 if student do
                   %{
                     "id" => student.id,
                     "name" => student.name,
                     "email" => student.email
                   }
                 else
                   nil
                 end
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{user_account_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    logged_in_event
  end

  defp assert_user_session_for_new_user(event, auth, username, root, student \\ nil) do
    preregistered_user =
      if student do
        expected_preregistered_user(student, auth.principal_id, student.version + 1, @now)
      end

    assert_persisted_user_session(
      event,
      auth,
      %{username: username, root: root, version: 1, created_at: @now, updated_at: @now},
      %{version: 1, created_at: @now, updated_at: @now},
      preregistered_user
    )
  end

  defp assert_user_session_for_existing_user(
         event,
         auth,
         %UserAccount{} = user_account,
         switch_edu_id,
         root,
         updated,
         student \\ nil
       ) do
    # A pre-existing Switch edu-ID keeps its created/updated timestamps (the
    # login data deliberately matches its name so nothing is touched); only its
    # version is bumped and its used-at is refreshed. A brand new Switch edu-ID
    # (login data passed instead of a struct) is fully stamped at `@now`.
    switch_edu_id_attrs =
      case switch_edu_id do
        %SwitchEduId{} = existing ->
          %{
            version: existing.version + 1,
            created_at: existing.created_at,
            updated_at: existing.updated_at
          }

        _login_data ->
          %{version: 1, created_at: @now, updated_at: @now}
      end

    preregistered_user =
      if student do
        expected_preregistered_user(
          student,
          user_account.id,
          update_version_if(student, :student, updated),
          if(updated in [true, :student], do: @now, else: student.updated_at)
        )
      end

    assert_persisted_user_session(
      event,
      auth,
      %{
        username: user_account.username,
        root: root,
        version: update_version_if(user_account, :user_account, updated),
        created_at: user_account.created_at,
        updated_at: if(updated in [true, :user_account], do: @now, else: user_account.updated_at)
      },
      switch_edu_id_attrs,
      preregistered_user
    )
  end

  # Asserts the single persisted session (with its preloaded user account,
  # Switch edu-ID identity and preregistered user) by exact equality. Callers
  # supply the expected user-account and Switch edu-ID version/timestamps, which
  # is the only thing that differs between registration and login.
  defp assert_persisted_user_session(
         %StoredEvent{
           data: %{
             "switch_edu_id" => %{
               "id" => switch_edu_id_id,
               "first_name" => first_name,
               "last_name" => last_name,
               "swiss_edu_person_unique_id" => swiss_edu_person_unique_id
             },
             "client_ip_address" => client_ip_address,
             "client_user_agent" => client_user_agent
           }
         },
         %Authentication{
           principal_id: user_account_id,
           session_id: session_id,
           session_token: session_token
         },
         %{
           username: username,
           root: root,
           version: account_version,
           created_at: account_created_at,
           updated_at: account_updated_at
         },
         %{
           version: switch_edu_id_version,
           created_at: switch_edu_id_created_at,
           updated_at: switch_edu_id_updated_at
         },
         preregistered_user
       ) do
    assert [%UserSession{} = user_session] = all_user_sessions()

    assert user_session == %UserSession{
             __meta__: loaded(UserSession, "user_sessions"),
             id: session_id,
             token: session_token,
             created_at: @now,
             client_ip_address: client_ip_address,
             client_user_agent: client_user_agent,
             user_account: %UserAccount{
               __meta__: loaded(UserAccount, "user_accounts"),
               id: user_account_id,
               username: username,
               root: root,
               active: true,
               switch_edu_id: %SwitchEduId{
                 __meta__: loaded(SwitchEduId, "switch_edu_ids"),
                 id: switch_edu_id_id,
                 first_name: first_name,
                 last_name: last_name,
                 swiss_edu_person_unique_id: swiss_edu_person_unique_id,
                 version: switch_edu_id_version,
                 created_at: switch_edu_id_created_at,
                 updated_at: switch_edu_id_updated_at,
                 used_at: @now
               },
               switch_edu_id_id: switch_edu_id_id,
               preregistered_user: preregistered_user,
               preregistered_user_id: preregistered_user && preregistered_user.id,
               version: account_version,
               created_at: account_created_at,
               updated_at: account_updated_at
             },
             user_account_id: user_account_id,
             impersonated_user_account: nil,
             impersonated_user_account_id: nil
           }
  end

  defp expected_preregistered_user(student, user_account_id, version, updated_at) do
    %PreregisteredUser{
      __meta__: loaded(PreregisteredUser, "students"),
      id: student.id,
      name: student.name,
      email: student.email,
      username: student.username,
      username_confirmed: student.username_confirmed,
      active: true,
      group: not_loaded(:group, PreregisteredUser),
      group_id: student.class_id,
      user_account: not_loaded(:user_account, PreregisteredUser),
      user_account_id: user_account_id,
      version: version,
      updated_at: updated_at
    }
  end

  defp all_user_sessions do
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
  end

  defp update_version_if(%{version: version}, _key, true), do: version + 1

  defp update_version_if(%{version: version}, update, update) when is_atom(update),
    do: version + 1

  defp update_version_if(%{version: version}, _key, _update), do: version
end
