defmodule ArchiDep.Accounts.SessionsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Accounts.Behaviour
  alias ArchiDep.Accounts.Context
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Clock
  alias ArchiDep.Repo
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.AccountsTestHelpers
  alias ArchiDep.Support.Factory
  alias Ecto.UUID

  # Pinned instant returned by the injected clock. The 30-day session validity
  # window is derived from this same clock, so session fixtures use
  # `@now`-relative creation times and the refreshed `used_at` is pinned exactly
  # to `@now` (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]
  @session_validity_in_seconds 30 * 24 * 60 * 60

  # Validating a session refreshes the session row in place and emits no event,
  # so the row counts never change; the meaningful assertions are on the
  # refreshed row's contents and the absence of any stored event.
  @affected_tables [UserSession, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      fetch_active_sessions: protect({Context, :fetch_active_sessions, 1}, Behaviour),
      validate_session_token: protect({Context, :validate_session_token, 2}, Behaviour),
      validate_session_id: protect({Context, :validate_session_id, 2}, Behaviour),
      user_account: protect({Context, :user_account, 1}, Behaviour)
    }
  end

  describe "fetch_active_sessions/1" do
    test "returns the user's active sessions, most recently created first", %{
      fetch_active_sessions: fetch_active_sessions
    } do
      account =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      # Inserted out of chronological order to prove the query sorts rather than
      # returning insertion order. There is a single sort key (created_at desc)
      # and no tie-break column, so the fixtures use distinct timestamps.
      middle =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -2, :hour)
        )

      newest =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      oldest =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -3, :hour)
        )

      # Excluded: an expired session of the same user, and another user's
      # session.
      AccountsFactory.insert(:user_session,
        user_account: account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -31, :day)
      )

      other_account =
        AccountsFactory.insert(:user_account,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      AccountsFactory.insert(:user_session,
        user_account: other_account,
        impersonated_user_account: nil,
        created_at: DateTime.add(@now, -1, :hour)
      )

      auth = authentication_for(account)

      previous_counts = count_rows(@affected_tables)

      assert fetch_active_sessions.(auth) == [
               active_session(newest, account),
               active_session(middle, account),
               active_session(oldest, account)
             ]

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "returns an empty list when the user has no active sessions", %{
      fetch_active_sessions: fetch_active_sessions
    } do
      account =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      assert fetch_active_sessions.(authentication_for(account)) == []
      assert_no_stored_events!()
    end
  end

  describe "validate_session_token/2" do
    test "validates an active root session and refreshes it", %{
      validate_session_token: validate_session_token
    } do
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

      metadata = client_metadata()

      previous_counts = count_rows(@affected_tables)

      assert {:ok, auth} = validate_session_token.(session.token, metadata)
      assert auth == expected_authentication(session, account)

      assert_session_refreshed(session, metadata)

      # Validation refreshes the row in place: no rows added or removed, and no
      # event emitted.
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "validates an active student session and refreshes it", %{
      validate_session_token: validate_session_token
    } do
      {account, _student} = AccountsTestHelpers.register_active_student(@now)

      session =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      metadata = client_metadata()

      previous_counts = count_rows(@affected_tables)

      assert {:ok, auth} = validate_session_token.(session.token, metadata)
      assert auth == expected_authentication(session, account)

      assert_session_refreshed(session, metadata)

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "rejects an unknown session token", %{validate_session_token: validate_session_token} do
      assert validate_session_token.("unknown-token", client_metadata()) ==
               {:error, :session_not_found}

      assert_no_stored_events!()
    end

    test "rejects an expired session", %{validate_session_token: validate_session_token} do
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

      previous_counts = count_rows(@affected_tables)

      assert validate_session_token.(session.token, client_metadata()) ==
               {:error, :session_not_found}

      assert_session_untouched(session)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "rejects a session of an inactive user account", %{
      validate_session_token: validate_session_token
    } do
      account =
        AccountsFactory.insert(:user_account,
          root: true,
          active: false,
          switch_edu_id: nil,
          now: @now
        )

      session =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      previous_counts = count_rows(@affected_tables)

      assert validate_session_token.(session.token, client_metadata()) ==
               {:error, :session_not_found}

      assert_session_untouched(session)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end
  end

  describe "validate_session_id/2" do
    test "validates an active session and refreshes it", %{
      validate_session_id: validate_session_id
    } do
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

      metadata = client_metadata()

      previous_counts = count_rows(@affected_tables)

      assert {:ok, auth} = validate_session_id.(session.id, metadata)
      assert auth == expected_authentication(session, account)

      assert_session_refreshed(session, metadata)

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "rejects an unknown session ID", %{validate_session_id: validate_session_id} do
      assert validate_session_id.(UUID.generate(), client_metadata()) ==
               {:error, :session_not_found}

      assert_no_stored_events!()
    end

    test "rejects an expired session", %{validate_session_id: validate_session_id} do
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

      previous_counts = count_rows(@affected_tables)

      assert validate_session_id.(session.id, client_metadata()) == {:error, :session_not_found}

      assert_session_untouched(session)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "rejects a session of an inactive user account", %{
      validate_session_id: validate_session_id
    } do
      account =
        AccountsFactory.insert(:user_account,
          root: true,
          active: false,
          switch_edu_id: nil,
          now: @now
        )

      session =
        AccountsFactory.insert(:user_session,
          user_account: account,
          impersonated_user_account: nil,
          created_at: DateTime.add(@now, -1, :hour)
        )

      previous_counts = count_rows(@affected_tables)

      assert validate_session_id.(session.id, client_metadata()) == {:error, :session_not_found}

      assert_session_untouched(session)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end
  end

  describe "user_account/1" do
    test "returns the user account of the authenticated principal", %{user_account: user_account} do
      account =
        AccountsFactory.insert(:user_account,
          username: :generate,
          root: true,
          active: true,
          switch_edu_id: nil,
          now: @now
        )

      assert user_account.(authentication_for(account)) == account
      assert_no_stored_events!()
    end
  end

  defp authentication_for(account),
    do:
      Factory.build(:authentication,
        principal_id: account.id,
        username: account.username,
        root: account.root,
        impersonated_id: nil
      )

  defp client_metadata,
    do: Factory.build(:client_metadata, ip_address: {192, 168, 1, 1}, user_agent: "Test Agent")

  # The query preloads the user account (with its — here empty — Switch edu-ID
  # and preregistered user) but not the impersonated user account.
  defp active_session(session, account),
    do: %{
      session
      | user_account: account,
        impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
    }

  defp expected_authentication(session, account),
    do: %Authentication{
      principal_id: account.id,
      username: account.username,
      root: account.root,
      session_id: session.id,
      session_token: session.token,
      session_expires_at: DateTime.add(session.created_at, @session_validity_in_seconds, :second),
      impersonated_id: nil
    }

  defp assert_session_refreshed(session, metadata) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | used_at: @now,
               client_ip_address: ClientMetadata.serialize_ip_address(metadata.ip_address),
               client_user_agent: metadata.user_agent,
               user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }
  end

  defp assert_session_untouched(session) do
    assert Repo.get!(UserSession, session.id) == %{
             session
             | user_account: not_loaded(:user_account, UserSession),
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession)
           }
  end
end
