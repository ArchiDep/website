defmodule ArchiDep.Accounts.DeleteSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.AccountsTestHelpers
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  # Pinned instant returned by the injected clock; the deletion event's
  # `occurred_at` is asserted against it, and the validity window is derived from
  # it (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  @affected_tables [UserSession, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{delete_session: protect({Context, :delete_session, 2}, Behaviour)}
  end

  test "a root user deletes one of their own sessions", %{delete_session: delete_session} do
    account =
      AccountsFactory.insert(:user_account, root_account_attrs(@now))

    session = AccountsFactory.insert(:user_session, session_attrs(account, @now))

    auth = authentication_for(account)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, returned} = delete_session.(auth, session.id)
    assert returned == fetched_session(session, account)

    session
    |> assert_session_deleted_event(account, nil, auth.principal_id)
    |> assert_session_gone()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "a student deletes one of their own sessions", %{delete_session: delete_session} do
    {account, student} = register_active_student(@now)

    session = AccountsFactory.insert(:user_session, session_attrs(account, @now))

    auth = authentication_for(account)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, returned} = delete_session.(auth, session.id)
    assert returned.id == session.id

    # The deletion event carries the student's preregistered-user identity, so
    # this pins that deletion works — and is audited — for a student account, not
    # only a root one.
    session
    |> assert_session_deleted_event(account, student, auth.principal_id)
    |> assert_session_gone()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "a root user can delete any user's session", %{delete_session: delete_session} do
    account =
      AccountsFactory.insert(:user_account, root_account_attrs(@now))

    session = AccountsFactory.insert(:user_session, session_attrs(account, @now))

    # A different principal, acting as root, deletes the session: the event is
    # stored on the session owner's stream but initiated by the root user.
    root_auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, returned} = delete_session.(root_auth, session.id)
    assert returned == fetched_session(session, account)

    session
    |> assert_session_deleted_event(account, nil, root_auth.principal_id)
    |> assert_session_gone()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "an expired session can still be deleted", %{delete_session: delete_session} do
    # Deletion fetches the session without the validity check that login uses, so
    # a user can still revoke a session that has already expired.
    account =
      AccountsFactory.insert(:user_account, root_account_attrs(@now))

    session =
      AccountsFactory.insert(
        :user_session,
        session_attrs(account, @now, created_at: DateTime.add(@now, -31, :day))
      )

    auth = authentication_for(account)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, returned} = delete_session.(auth, session.id)
    assert returned == fetched_session(session, account)

    session
    |> assert_session_deleted_event(account, nil, auth.principal_id)
    |> assert_session_gone()

    assert_row_count_diff(previous_counts, %{UserSession => -1, StoredEvent => 1})
  end

  test "deleting another user's session is masked as not found", %{
    delete_session: delete_session
  } do
    # A non-root user who does not own the session must not be able to tell
    # whether it exists, so the unauthorized deletion is masked as not-found
    # rather than raising or returning an authorization error.
    account =
      AccountsFactory.insert(:user_account, root_account_attrs(@now))

    session = AccountsFactory.insert(:user_session, session_attrs(account, @now))

    other_user_auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert delete_session.(other_user_auth, session.id) == {:error, :session_not_found}

    assert_session_untouched(session)
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "deleting an unknown session returns not found", %{delete_session: delete_session} do
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_session.(auth, UUID.generate()) == {:error, :session_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "deleting a session with an invalid ID returns not found", %{
    delete_session: delete_session
  } do
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    # A 36-byte string satisfies the behaviour's `String.t()` contract (so the
    # protected call runs) but is not a valid UUID, so the use case's own
    # `validate_uuid` guard rejects it.
    assert delete_session.(auth, String.duplicate("x", 36)) == {:error, :session_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  defp authentication_for(account),
    do:
      Factory.build(:authentication,
        principal_id: account.id,
        username: account.username,
        root: account.root,
        impersonated_id: nil
      )

  # The use case echoes back the session it fetched by id: the (root) user
  # account is preloaded with its — here empty — Switch edu-ID and preregistered
  # user, and the impersonated user account is loaded as `nil`.
  defp fetched_session(session, account),
    do: %{session | user_account: account, impersonated_user_account: nil}

  defp assert_session_deleted_event(session, account, preregistered_user, initiator_id) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "accounts:user-accounts:#{account.id}",
             version: account.version,
             schema_version: 1,
             type: "archidep/accounts/session-deleted",
             data: %{
               "user_account" => %{"id" => account.id, "username" => account.username},
               "switch_edu_id" => nil,
               "preregistered_user" => preregistered_user_data(preregistered_user),
               "session_id" => session.id
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

  defp assert_session_gone(session) do
    refute Repo.exists?(from(us in UserSession, where: us.id == ^session.id))
    session
  end
end
