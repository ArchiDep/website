defmodule ArchiDep.Accounts.Schemas.UserSessionTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.AccountsFactory
  import ArchiDep.Support.TokenTestHelpers
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata
  alias Ecto.Changeset

  @now ~U[2024-01-01 08:00:00.000000Z]
  # A session is valid for 30 days from its creation.
  @validity_in_seconds 30 * 24 * 60 * 60

  describe "new_session/3" do
    test "builds a session with a secure random token and the serialized client metadata" do
      account = build(:user_account)
      client_metadata = %ClientMetadata{ip_address: {1, 2, 3, 4}, user_agent: "Mozilla/5.0"}

      changeset = UserSession.new_session(account, client_metadata, @now)

      assert errors_on(changeset) == %{}
      session = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(session.id)
      assert_secure_random_token(session.token)

      assert session == %UserSession{
               id: session.id,
               token: session.token,
               created_at: @now,
               used_at: nil,
               client_ip_address: "1.2.3.4",
               client_user_agent: "Mozilla/5.0",
               user_account: account,
               user_account_id: account.id,
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession),
               impersonated_user_account_id: nil
             }
    end

    test "leaves the client IP address nil when the metadata carries none" do
      account = build(:user_account)
      client_metadata = %ClientMetadata{ip_address: nil, user_agent: nil}

      changeset = UserSession.new_session(account, client_metadata, @now)

      assert errors_on(changeset) == %{}
      session = Changeset.apply_changes(changeset)
      assert {:ok, _uuid} = Ecto.UUID.cast(session.id)
      assert_secure_random_token(session.token)

      assert session == %UserSession{
               id: session.id,
               token: session.token,
               created_at: @now,
               used_at: nil,
               client_ip_address: nil,
               client_user_agent: nil,
               user_account: account,
               user_account_id: account.id,
               impersonated_user_account: not_loaded(:impersonated_user_account, UserSession),
               impersonated_user_account_id: nil
             }
    end
  end

  describe "expires_at/1" do
    test "is 30 days after the session was created" do
      session = build(:user_session, created_at: @now)

      assert UserSession.expires_at(session) == DateTime.add(@now, @validity_in_seconds, :second)
    end
  end

  describe "authentication/1" do
    test "describes the session owner when not impersonating" do
      account = build(:user_account, username: "alice", root: true)

      session =
        build(:user_session,
          created_at: @now,
          user_account: account,
          user_account_id: account.id,
          impersonated_user_account: nil,
          impersonated_user_account_id: nil
        )

      assert UserSession.authentication(session) == %Authentication{
               principal_id: account.id,
               username: "alice",
               root: true,
               session_id: session.id,
               session_token: session.token,
               session_expires_at: DateTime.add(@now, @validity_in_seconds, :second),
               impersonated_id: nil
             }
    end

    test "describes the impersonated account, keeping the session's own id and token" do
      owner = build(:user_account, username: "alice", root: true)
      impersonated = build(:user_account, username: "bob", root: false)

      session =
        build(:user_session,
          created_at: @now,
          user_account: owner,
          user_account_id: owner.id,
          impersonated_user_account: impersonated,
          impersonated_user_account_id: impersonated.id
        )

      assert UserSession.authentication(session) == %Authentication{
               principal_id: impersonated.id,
               username: "bob",
               root: false,
               session_id: session.id,
               session_token: session.token,
               session_expires_at: DateTime.add(@now, @validity_in_seconds, :second),
               impersonated_id: impersonated.id
             }
    end
  end

  describe "current_session?/2" do
    test "is true when the authentication carries this session's ID" do
      session = build(:user_session)

      assert UserSession.current_session?(session, authentication(session.id))
    end

    test "is false for a different session ID" do
      session = build(:user_session)

      refute UserSession.current_session?(session, authentication(Ecto.UUID.generate()))
    end
  end

  describe "impersonate/2" do
    test "targets another account for impersonation" do
      owner = build(:user_account)

      session =
        build(:user_session,
          user_account: owner,
          user_account_id: owner.id,
          impersonated_user_account: nil,
          impersonated_user_account_id: nil
        )

      target = build(:user_account)

      changeset = UserSession.impersonate(session, target)

      assert Changeset.apply_changes(changeset) == %{
               session
               | impersonated_user_account: target,
                 impersonated_user_account_id: target.id
             }
    end
  end

  describe "stop_impersonating/1" do
    test "clears the impersonated account" do
      impersonated = build(:user_account)

      session =
        build(:user_session,
          impersonated_user_account: impersonated,
          impersonated_user_account_id: impersonated.id
        )

      changeset = UserSession.stop_impersonating(session)

      assert Changeset.apply_changes(changeset) == %{
               session
               | impersonated_user_account: nil,
                 impersonated_user_account_id: nil
             }
    end

    test "is a no-op when the session is not impersonating" do
      session =
        build(:user_session,
          impersonated_user_account: nil,
          impersonated_user_account_id: nil
        )

      changeset = UserSession.stop_impersonating(session)

      assert changeset.changes == %{}
    end
  end

  # `current_session?/2` only compares session IDs, but `Authentication`
  # enforces its other keys, so build a full struct around the session id under
  # test.
  defp authentication(session_id),
    do: %Authentication{
      principal_id: Ecto.UUID.generate(),
      username: "alice",
      root: false,
      session_id: session_id,
      session_token: "token",
      session_expires_at: @now
    }
end
