defmodule ArchiDepWeb.Profile.CurrentSessionsLiveTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Support.AccountsFactory
  alias ArchiDepWeb.Profile.CurrentSessionsLive

  @now ~U[2026-06-19 12:00:00Z]
  @session_validity_in_days 30
  @two_days_in_seconds 2 * 24 * 60 * 60

  # A session's expiration is its creation time plus the fixed validity window,
  # so building a session that expires at a chosen instant means creating it
  # exactly one validity window earlier.
  defp session_expiring_at(expires_at),
    do:
      AccountsFactory.build(:user_session,
        created_at: DateTime.add(expires_at, -@session_validity_in_days, :day)
      )

  describe "expired?/2" do
    test "a session that expires after the current time is not expired" do
      session = session_expiring_at(DateTime.add(@now, 1, :second))
      refute CurrentSessionsLive.expired?(session, @now)
    end

    test "a session that expires exactly at the current time is not expired" do
      session = session_expiring_at(@now)
      refute CurrentSessionsLive.expired?(session, @now)
    end

    test "a session that expired before the current time is expired" do
      session = session_expiring_at(DateTime.add(@now, -1, :second))
      assert CurrentSessionsLive.expired?(session, @now)
    end
  end

  describe "expires_soon?/2" do
    test "a session that expires more than two days from now does not expire soon" do
      session = session_expiring_at(DateTime.add(@now, @two_days_in_seconds + 1, :second))
      refute CurrentSessionsLive.expires_soon?(session, @now)
    end

    test "a session that expires exactly two days from now does not expire soon" do
      session = session_expiring_at(DateTime.add(@now, @two_days_in_seconds, :second))
      refute CurrentSessionsLive.expires_soon?(session, @now)
    end

    test "a session that expires within two days expires soon" do
      session = session_expiring_at(DateTime.add(@now, @two_days_in_seconds - 1, :second))
      assert CurrentSessionsLive.expires_soon?(session, @now)
    end

    test "an already-expired session expires soon" do
      session = session_expiring_at(DateTime.add(@now, -1, :second))
      assert CurrentSessionsLive.expires_soon?(session, @now)
    end
  end
end
