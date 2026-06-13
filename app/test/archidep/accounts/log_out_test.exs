defmodule ArchiDep.Accounts.LogOutTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.TelemetryTestHelpers
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.AccountsTestHelpers
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock; the logout event's
  # `occurred_at` is asserted against it, and the 30-day session validity window
  # is derived from it (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  @logout_telemetry_event [:archidep, :accounts, :auth, :logout]

  @affected_tables [UserSession, StoredEvent]

  setup :verify_on_exit!

  setup context do
    stub(Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @logout_telemetry_event)
    :ok
  end

  setup_all do
    %{log_out: protect({Context, :log_out, 1}, Behaviour)}
  end

  test "a root user logs out of the current session", %{log_out: log_out} do
    account =
      AccountsFactory.insert(:user_account,
        username: :generate,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    session =
      AccountsFactory.insert(:user_session,
        user_account: account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -1, :hour)
      )

    auth = authentication_for(account, session)

    previous_counts = count_rows(@affected_tables)

    assert log_out.(auth) == :ok

    session
    |> assert_logged_out_event(account, nil)
    |> assert_logout_telemetry(account)
    |> assert_session_deleted()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "a student logs out of the current session", %{log_out: log_out} do
    {account, student} = AccountsTestHelpers.register_active_student(@now)

    session =
      AccountsFactory.insert(:user_session,
        user_account: account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -1, :hour)
      )

    auth = authentication_for(account, session)

    previous_counts = count_rows(@affected_tables)

    assert log_out.(auth) == :ok

    session
    |> assert_logged_out_event(account, student)
    |> assert_logout_telemetry(account)
    |> assert_session_deleted()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "logging out with an unknown session token does nothing", %{log_out: log_out} do
    account =
      AccountsFactory.insert(:user_account,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    session =
      AccountsFactory.insert(:user_session,
        user_account: account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -1, :hour)
      )

    auth = Map.put(authentication_for(account, session), :session_token, "unknown-session-token")

    previous_counts = count_rows(@affected_tables)

    assert log_out.(auth) == {:error, :session_not_found}

    assert_session_untouched(session)
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_received {:telemetry_event, @logout_telemetry_event, _data}
  end

  test "logging out of an expired session does nothing", %{log_out: log_out} do
    account =
      AccountsFactory.insert(:user_account,
        root: true,
        active: true,
        switch_edu_id: nil,
        now: @now
      )

    session =
      AccountsFactory.insert(:user_session,
        user_account: account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -31, :day)
      )

    auth = authentication_for(account, session)

    previous_counts = count_rows(@affected_tables)

    assert log_out.(auth) == {:error, :session_not_found}

    assert_session_untouched(session)
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_received {:telemetry_event, @logout_telemetry_event, _data}
  end

  defp authentication_for(account, session),
    do:
      Factory.build(:authentication,
        principal_id: account.id,
        username: account.username,
        root: account.root,
        session_id: session.id,
        session_token: session.token,
        impersonated_id: nil
      )

  defp assert_logged_out_event(session, account, preregistered_user) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{account.id}",
             version: account.version,
             type: "archidep/accounts/user-logged-out",
             data: %{
               "user_account" => %{"id" => account.id, "username" => account.username},
               "switch_edu_id" => nil,
               "preregistered_user" => preregistered_user_data(preregistered_user),
               "session_id" => session.id
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{account.id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    session
  end

  defp assert_logout_telemetry(session, account) do
    assert assert_telemetry_event!(@logout_telemetry_event) == %{
             measurements: %{},
             metadata: %{principal_id: account.id},
             config: nil
           }

    session
  end

  defp assert_session_deleted(session) do
    refute Repo.exists?(from(us in UserSession, where: us.id == ^session.id))
    session
  end

  defp assert_session_untouched(session) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }
  end

  defp preregistered_user_data(nil), do: nil

  defp preregistered_user_data(student),
    do: %{"id" => student.id, "name" => student.name, "email" => student.email}
end
