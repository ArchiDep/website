defmodule ArchiDep.Accounts.LogInOrRegisterWithLinkTest do
  use ArchiDep.Support.DataCase, async: true

  import Ecto.Query, only: [from: 2]
  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  import ArchiDep.Support.TelemetryTestHelpers
  import ArchiDep.Support.TokenTestHelpers
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Events.PreregisteredUserLinkedToUserAccount
  alias ArchiDep.Accounts.PubSub
  alias ArchiDep.Accounts.Schemas.LoginLink
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.Clock
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]
  @session_validity_in_seconds 30 * 24 * 60 * 60

  @login_telemetry_event [:archidep, :accounts, :auth, :login]

  # Every table this use case can affect. Snapshot all of them with
  # `count_rows/1` before each call so the row-count diff catches a stray write
  # to any of them, not just the ones a given test happens to think about (see
  # `docs/testing.md`).
  @affected_tables [UserAccount, UserSession, StoredEvent, LoginLink]

  setup :verify_on_exit!

  setup context do
    stub(Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @login_telemetry_event)
    :ok
  end

  setup_all do
    %{
      log_in_or_register_with_link:
        protect({Context, :log_in_or_register_with_link, 2}, Behaviour)
    }
  end

  test "register a new student user account with a login link", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, auth} = log_in_or_register_with_link.(login_link.token, metadata)

    auth
    |> assert_auth(nil, false)
    |> assert_login_telemetry()
    |> assert_registered_with_link_event(metadata, login_link, student)
    |> assert_persisted_session_for_new_user(auth, student)

    assert_login_link_used(login_link)
    # Registration creates the user account, its session, the registration event
    # and the preregistered-user linkage event; the link is consumed in place
    # (no new link row).
    assert_row_count_diff(previous_counts, %{UserAccount => 1, UserSession => 1, StoredEvent => 2})

    assert_preregistered_user_broadcast(broadcasts, student, auth.principal_id)
  end

  test "log in an existing student user account with a login link", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    user_account =
      AccountsFactory.insert(:user_account, student_user_account_attrs(student, active: true))

    link_student_to_user_account(student, user_account)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, auth} = log_in_or_register_with_link.(login_link.token, metadata)

    auth
    |> assert_auth(user_account.username, user_account.root)
    |> assert_login_telemetry()
    |> assert_logged_in_with_link_event(metadata, login_link, user_account, student)
    |> assert_persisted_session_for_existing_user(auth, user_account, student)

    assert_login_link_used(login_link)
    # The existing account is reused (not duplicated): only a session and the
    # event are added, and the link is consumed in place.
    assert_row_count_diff(previous_counts, %{UserSession => 1, StoredEvent => 1})
    # The existing account is reused as-is, so the preregistered user is not
    # touched and nothing is broadcast.
    refute_preregistered_user_broadcast(broadcasts)
  end

  test "an unknown login link token cannot be used to log in", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} =
             log_in_or_register_with_link.(:crypto.strong_rand_bytes(100), metadata)

    assert_no_login_side_effects(previous_counts)
  end

  test "a deactivated login link cannot be used to log in", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    login_link =
      AccountsFactory.insert(
        :login_link,
        login_link_attrs(preregistered_user_id: student.id, active: false)
      )

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "an already used login link cannot be used again", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    login_link =
      AccountsFactory.insert(
        :login_link,
        login_link_attrs(preregistered_user_id: student.id, used_at: @now)
      )

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "a new student cannot register with a login link when their group is inactive", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: false, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "an existing student cannot log in with a login link when their group is inactive", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: false, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    user_account =
      AccountsFactory.insert(:user_account, student_user_account_attrs(student, active: true))

    link_student_to_user_account(student, user_account)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    assert_user_account_untouched(user_account)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "a student with an inactive user account cannot log in with a login link", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    user_account =
      AccountsFactory.insert(:user_account, student_user_account_attrs(student, active: false))

    link_student_to_user_account(student, user_account)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    assert_user_account_untouched(user_account)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "a login link must never authenticate a root account", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    class = CourseFactory.insert(:class, active: true, now: @now)
    student = CourseFactory.insert(:student, active: true, class: class, user: nil, now: @now)

    broadcasts = subscribe_to_preregistered_user(student)

    # Security invariant: a login link is a bearer token in a URL and must never
    # grant the highest-privilege principal. A root account is standalone — its
    # own `student_id` is null per the user_accounts_root_or_student_check
    # constraint — but a student's `user_account_id` can still point at it,
    # which loads the root account on the link's preregistered user and would
    # otherwise reach the account-reuse branch. An active root account so linked
    # must still fail closed.
    user_account =
      AccountsFactory.insert(:user_account,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    link_student_to_user_account(student, user_account)

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(preregistered_user_id: student.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    assert_user_account_untouched(user_account)
    refute_preregistered_user_broadcast(broadcasts)
    assert_login_link_untouched(login_link)
  end

  test "a login link associated with a user account cannot be used to log in", %{
    log_in_or_register_with_link: log_in_or_register_with_link
  } do
    # A standalone account (not linked to a student) must be a root account to
    # satisfy the user_accounts_root_or_student_check constraint.
    user_account =
      AccountsFactory.insert(:user_account,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    login_link =
      AccountsFactory.insert(:login_link, login_link_attrs(user_account_id: user_account.id))

    metadata = Factory.build(:client_metadata)

    previous_counts = count_rows(@affected_tables)

    assert {:error, :invalid_link} = log_in_or_register_with_link.(login_link.token, metadata)

    assert_no_login_side_effects(previous_counts)
    assert_user_account_untouched(user_account)
    assert_login_link_untouched(login_link)
  end

  defp login_link_attrs(extra) do
    Keyword.merge([active: true, created_at: @now], extra)
  end

  defp student_user_account_attrs(student, extra) do
    Keyword.merge(
      [root: false, switch_edu_id: nil, preregistered_user_id: student.id, now: @now],
      extra
    )
  end

  defp assert_auth(auth, username, root) do
    assert %Authentication{
             principal_id: user_account_id,
             session_id: session_id,
             session_token: session_token
           } = auth

    assert_secure_random_token(session_token)

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
             metadata: %{method: :link, principal_id: principal_id},
             config: nil
           }

    auth
  end

  defp refute_login_telemetry do
    refute_received {:telemetry_event, @login_telemetry_event, _data}
  end

  # Asserts the full set of effects that must NOT happen on a rejected login: no
  # rows added or removed in any watched table (no account, session or link
  # created), no stored event and no telemetry. Callers add the assertions that
  # are specific to the scenario (login link untouched, user account untouched,
  # no broadcast). `previous_counts` must be captured before the call.
  defp assert_no_login_side_effects(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_login_telemetry()
  end

  # Subscribes the two topics a preregistered-user-updated broadcast reaches —
  # the preregistered user's own topic and its user group's topic — each in its
  # own collector, so each topic's delivery is asserted on its own rather than
  # funnelled into one indistinguishable mailbox.
  defp subscribe_to_preregistered_user(%{id: id, class_id: class_id}) do
    %{
      specific: collect_broadcasts(fn -> PubSub.subscribe_preregistered_user(id) end),
      group:
        collect_broadcasts(fn -> PubSub.subscribe_user_group_preregistered_users(class_id) end)
    }
  end

  # Asserts the preregistered-user-updated message reached both topics the use
  # case publishes to — the preregistered user's own topic and its user group's
  # topic — each carrying the linkage event and its reference, and nothing else.
  # Every reference field is known up front — the version and `occurred_at` from
  # the linkage, and the causation/correlation IDs from the registration event
  # that caused it — so only the two event IDs are read back from the database.
  defp assert_preregistered_user_broadcast(broadcasts, student, user_account_id) do
    registration_id =
      Repo.one!(
        from(e in StoredEvent,
          where: e.stream == ^"accounts:user-accounts:#{user_account_id}",
          select: e.id
        )
      )

    linkage_id =
      Repo.one!(
        from(e in StoredEvent,
          where: e.stream == ^"accounts:preregistered-users:#{student.id}",
          select: e.id
        )
      )

    message =
      {:preregistered_user_updated,
       %PreregisteredUserLinkedToUserAccount{
         preregistered_user_id: student.id,
         user_account: %{id: user_account_id, username: nil, active: true, version: 1}
       },
       %EventReference{
         id: linkage_id,
         causation_id: registration_id,
         correlation_id: registration_id,
         version: student.version + 1,
         occurred_at: @now
       }}

    assert received_broadcasts(broadcasts.specific) == [message]
    assert received_broadcasts(broadcasts.group) == [message]
  end

  # Asserts neither topic carried a preregistered-user-updated broadcast.
  defp refute_preregistered_user_broadcast(broadcasts) do
    assert received_broadcasts(broadcasts.specific) == []
    assert received_broadcasts(broadcasts.group) == []
  end

  defp link_student_to_user_account(%{id: student_id}, %UserAccount{id: user_account_id}) do
    {1, nil} =
      Repo.update_all(from(s in Student, where: s.id == ^student_id),
        set: [user_id: user_account_id]
      )

    :ok
  end

  defp assert_registered_with_link_event(
         %Authentication{principal_id: user_account_id, session_id: session_id},
         client_metadata,
         login_link,
         student
       ) do
    assert [%StoredEvent{} = linkage_event, %StoredEvent{} = registered_event] =
             Enum.sort_by(fetch_new_stored_events(), & &1.type)

    assert registered_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: registered_event.id,
             stream: "accounts:user-accounts:#{user_account_id}",
             version: 1,
             type: "archidep/accounts/user-registered-with-link",
             data:
               event_data(login_link, client_metadata, session_id, student, %{
                 "id" => user_account_id,
                 "username" => nil,
                 "root" => false
               }),
             meta: %{},
             initiator: "accounts:user-accounts:#{user_account_id}",
             causation_id: registered_event.id,
             correlation_id: registered_event.id,
             occurred_at: @now,
             entity: nil
           }

    assert linkage_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: linkage_event.id,
             stream: "accounts:preregistered-users:#{student.id}",
             version: student.version + 1,
             type: "archidep/accounts/preregistered-user-linked-to-user-account",
             data: %{
               "preregistered_user_id" => student.id,
               "user_account" => %{
                 "id" => user_account_id,
                 "username" => nil,
                 "active" => true,
                 "version" => 1
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{user_account_id}",
             causation_id: registered_event.id,
             correlation_id: registered_event.id,
             occurred_at: @now,
             entity: nil
           }

    registered_event
  end

  defp assert_logged_in_with_link_event(
         %Authentication{principal_id: user_account_id, session_id: session_id},
         client_metadata,
         login_link,
         %UserAccount{id: user_account_id} = user_account,
         student
       ) do
    assert [%StoredEvent{id: event_id} = logged_in_event] = fetch_new_stored_events()

    assert logged_in_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{user_account_id}",
             version: user_account.version,
             type: "archidep/accounts/user-logged-in-with-link",
             data:
               event_data(login_link, client_metadata, session_id, student, %{
                 "id" => user_account_id,
                 "username" => user_account.username,
                 "root" => user_account.root
               }),
             meta: %{},
             initiator: "accounts:user-accounts:#{user_account_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    logged_in_event
  end

  defp event_data(login_link, client_metadata, session_id, student, user_account_data) do
    %{
      "login_link" => %{"id" => login_link.id},
      "user_account" => user_account_data,
      "session_id" => session_id,
      "client_ip_address" => serialize_ip(client_metadata),
      "client_user_agent" => client_metadata.user_agent,
      "preregistered_user" => %{
        "id" => student.id,
        "name" => student.name,
        "email" => student.email
      }
    }
  end

  defp assert_persisted_session_for_new_user(event, auth, student) do
    preregistered_user =
      expected_preregistered_user(student, auth.principal_id, student.version + 1, @now)

    assert_persisted_user_session(
      event,
      auth,
      %{username: nil, root: false, version: 1, created_at: @now, updated_at: @now},
      preregistered_user
    )
  end

  defp assert_persisted_session_for_existing_user(
         event,
         auth,
         %UserAccount{} = user_account,
         student
       ) do
    # The existing account is reused unchanged, so its version and timestamps are
    # exactly what they were, and the preregistered user is left untouched.
    preregistered_user =
      expected_preregistered_user(student, user_account.id, student.version, student.updated_at)

    assert_persisted_user_session(
      event,
      auth,
      %{
        username: user_account.username,
        root: user_account.root,
        version: user_account.version,
        created_at: user_account.created_at,
        updated_at: user_account.updated_at
      },
      preregistered_user
    )
  end

  # Asserts the single persisted session (with its preloaded user account and
  # preregistered user) by exact equality. Login-link accounts never carry a
  # Switch edu-ID identity, so it is asserted as `nil`. Callers supply the
  # expected user-account version/timestamps, which is the only thing that
  # differs between registration and login.
  defp assert_persisted_user_session(
         %StoredEvent{
           data: %{
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
               switch_edu_id: nil,
               switch_edu_id_id: nil,
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

  # Asserts the login link row was marked as used: deactivated (the optimistic
  # lock flips `active` from true to false) and stamped with the pinned instant.
  defp assert_login_link_used(login_link) do
    assert Repo.get!(LoginLink, login_link.id) ==
             %{
               login_link
               | active: false,
                 used_at: @now,
                 preregistered_user: not_loaded(:preregistered_user, LoginLink),
                 user_account: not_loaded(:user_account, LoginLink)
             }
  end

  defp assert_login_link_untouched(login_link) do
    assert Repo.get!(LoginLink, login_link.id) ==
             %{
               login_link
               | preregistered_user: not_loaded(:preregistered_user, LoginLink),
                 user_account: not_loaded(:user_account, LoginLink)
             }
  end

  defp assert_user_account_untouched(user_account) do
    assert Repo.all(UserAccount) == [
             %{
               user_account
               | switch_edu_id: not_loaded(:switch_edu_id, UserAccount),
                 preregistered_user: not_loaded(:preregistered_user, UserAccount)
             }
           ]
  end

  defp all_user_sessions do
    Repo.all(
      from us in UserSession,
        join: ua in assoc(us, :user_account),
        left_join: pu in assoc(ua, :preregistered_user),
        left_join: sei in assoc(ua, :switch_edu_id),
        left_join: iua in assoc(us, :impersonated_user_account),
        preload: [
          user_account: {ua, preregistered_user: pu, switch_edu_id: sei},
          impersonated_user_account: iua
        ]
    )
  end

  defp serialize_ip(%{ip_address: ip_address}),
    do: ip_address |> truthy_then(&:inet.ntoa/1) |> truthy_then(&List.to_string/1)
end
