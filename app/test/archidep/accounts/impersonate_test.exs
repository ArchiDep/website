defmodule ArchiDep.Accounts.ImpersonateTest do
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
  alias Ecto.UUID

  # Pinned instant returned by the injected clock; the impersonation events'
  # `occurred_at` is asserted against it (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  @impersonate_telemetry_event [:archidep, :accounts, :auth, :impersonate]
  @stop_telemetry_event [:archidep, :accounts, :auth, :stop_impersonating]

  # Impersonation updates the session row in place (no insert/delete), so the
  # session count is unchanged; only the audit event is added.
  @affected_tables [UserSession, StoredEvent]

  setup :verify_on_exit!

  setup context do
    stub(Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @impersonate_telemetry_event)
    attach_telemetry_handler!(context, @stop_telemetry_event)
    :ok
  end

  setup_all do
    %{
      impersonate: protect({Context, :impersonate, 2}, Behaviour),
      stop_impersonating: protect({Context, :stop_impersonating, 1}, Behaviour)
    }
  end

  describe "impersonate/2" do
    test "a root user impersonates a student", %{impersonate: impersonate} do
      impersonator =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      session =
        AccountsFactory.insert(:user_session,
          user_account: impersonator,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      {target, student} = AccountsTestHelpers.register_active_student(@now)

      auth = authentication_for(impersonator, session)

      previous_counts = count_rows(@affected_tables)

      # The use case returns the impersonated account; the event below pins how
      # both accounts are represented.
      assert {:ok, returned} = impersonate.(auth, target.id)
      assert returned.id == target.id

      session
      |> assert_now_impersonating(target)
      |> assert_user_impersonated_event(impersonator, target, student, impersonator.id)
      |> assert_impersonate_telemetry(impersonator, target)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end

    test "a root user cannot impersonate themselves", %{impersonate: impersonate} do
      impersonator =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      session =
        AccountsFactory.insert(:user_session,
          user_account: impersonator,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      auth = authentication_for(impersonator, session)

      previous_counts = count_rows(@affected_tables)

      assert impersonate.(auth, impersonator.id) == {:error, :unauthorized}

      assert_not_impersonating(session)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_impersonation_telemetry()
    end

    test "a non-root user cannot impersonate anyone", %{impersonate: impersonate} do
      {target, _student} = AccountsTestHelpers.register_active_student(@now)

      auth = Factory.build(:authentication, root: false)

      previous_counts = count_rows(@affected_tables)

      assert impersonate.(auth, target.id) == {:error, :unauthorized}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_impersonation_telemetry()
    end

    test "impersonating an unknown user account returns not found", %{impersonate: impersonate} do
      auth = Factory.build(:authentication, root: true)

      previous_counts = count_rows(@affected_tables)

      assert impersonate.(auth, UUID.generate()) == {:error, :user_account_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_impersonation_telemetry()
    end

    test "impersonating with an invalid user account ID returns not found", %{
      impersonate: impersonate
    } do
      auth = Factory.build(:authentication, root: true)

      previous_counts = count_rows(@affected_tables)

      # A 36-byte string satisfies the behaviour's `UUID.t()` contract but is not
      # a valid UUID, so the use case's own `validate_uuid` guard rejects it.
      assert impersonate.(auth, String.duplicate("x", 36)) == {:error, :user_account_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_impersonation_telemetry()
    end
  end

  describe "stop_impersonating/1" do
    test "stop impersonating a student", %{stop_impersonating: stop_impersonating} do
      impersonator =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      {target, student} = AccountsTestHelpers.register_active_student(@now)

      session =
        AccountsFactory.insert(:user_session,
          user_account: impersonator,
          impersonated_user_account: target,
          created_at: DateTime.add(@now, -1, :hour)
        )

      auth = impersonating_authentication_for(session, target)

      previous_counts = count_rows(@affected_tables)

      assert stop_impersonating.(auth) == :ok

      session
      |> assert_not_impersonating()
      |> assert_user_stopped_impersonating_event(impersonator, target, student, target.id)
      |> assert_stop_telemetry(target)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end

    test "cannot stop impersonating when not impersonating", %{
      stop_impersonating: stop_impersonating
    } do
      auth = Factory.build(:authentication, root: true, impersonated_id: nil)

      previous_counts = count_rows(@affected_tables)

      assert stop_impersonating.(auth) == {:error, :unauthorized}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_impersonation_telemetry()
    end
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

  # While impersonating, the session's current principal is the impersonated
  # user, so the authentication reflects that user (and carries the impersonated
  # ID).
  defp impersonating_authentication_for(session, impersonated),
    do:
      Factory.build(:authentication,
        principal_id: impersonated.id,
        username: impersonated.username,
        root: impersonated.root,
        session_id: session.id,
        session_token: session.token,
        impersonated_id: impersonated.id
      )

  defp assert_now_impersonating(session, target) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | impersonated_user_account_id: target.id,
               user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }

    session
  end

  defp assert_not_impersonating(session) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | impersonated_user_account_id: nil,
               user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }

    session
  end

  defp assert_user_impersonated_event(session, impersonator, target, student, initiator_id),
    do:
      assert_impersonation_event(
        session,
        "archidep/accounts/user-impersonated",
        impersonator,
        target,
        student,
        initiator_id
      )

  defp assert_user_stopped_impersonating_event(
         session,
         impersonator,
         target,
         student,
         initiator_id
       ),
       do:
         assert_impersonation_event(
           session,
           "archidep/accounts/user-stopped-impersonating",
           impersonator,
           target,
           student,
           initiator_id
         )

  defp assert_impersonation_event(session, type, impersonator, target, student, initiator_id) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{impersonator.id}",
             version: impersonator.version,
             type: type,
             data: %{
               "session_id" => session.id,
               "user_account" => account_data(impersonator, nil),
               "impersonated_user_account" => account_data(target, student)
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{initiator_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    session
  end

  defp assert_impersonate_telemetry(session, impersonator, target) do
    assert assert_telemetry_event!(@impersonate_telemetry_event) == %{
             measurements: %{},
             metadata: %{principal_id: impersonator.id, impersonated_id: target.id},
             config: nil
           }

    session
  end

  defp assert_stop_telemetry(session, impersonated) do
    assert assert_telemetry_event!(@stop_telemetry_event) == %{
             measurements: %{},
             metadata: %{principal_id: impersonated.id},
             config: nil
           }

    session
  end

  # The account representation embedded in impersonation events. The accounts in
  # these tests carry no Switch edu-ID (that branch is exercised by the login
  # event tests), so `switch_edu_id` is always nil here; a student carries its
  # preregistered-user identity.
  defp account_data(account, student),
    do: %{
      "id" => account.id,
      "username" => account.username,
      "root" => account.root,
      "switch_edu_id" => nil,
      "preregistered_user" => preregistered_user_data(student)
    }

  defp preregistered_user_data(nil), do: nil

  defp preregistered_user_data(student),
    do: %{"id" => student.id, "name" => student.name, "email" => student.email}

  defp refute_impersonation_telemetry do
    refute_received {:telemetry_event, @impersonate_telemetry_event, _data}
    refute_received {:telemetry_event, @stop_telemetry_event, _data}
  end
end
