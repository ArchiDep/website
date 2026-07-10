defmodule ArchiDep.Servers.Schemas.ServerOwnerCountersTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.ServerOwnerCounters
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.ServersFactory

  describe "server limits" do
    test "the active-server limit is 1 and the server limit is 5" do
      assert ServerOwnerCounters.active_server_limit() == 1
      assert ServerOwnerCounters.server_limit() == 5
    end

    test "active_server_limit_reached?/1 is true from one active server" do
      refute ServerOwnerCounters.active_server_limit_reached?(
               ServersFactory.build(:server_owner_counters, active_server_count: 0)
             )

      assert ServerOwnerCounters.active_server_limit_reached?(
               ServersFactory.build(:server_owner_counters, active_server_count: 1)
             )
    end

    test "server_limit_reached?/1 is true from five servers" do
      refute ServerOwnerCounters.server_limit_reached?(
               ServersFactory.build(:server_owner_counters,
                 server_count: 4,
                 active_server_count: 0
               )
             )

      assert ServerOwnerCounters.server_limit_reached?(
               ServersFactory.build(:server_owner_counters,
                 server_count: 5,
                 active_server_count: 0
               )
             )
    end
  end

  describe "initial_changeset/1" do
    test "creates the counters row for an owner's first server" do
      %{id: user_account_id} = AccountsFactory.insert(:user_account, root: true)

      inserted = Repo.insert!(ServerOwnerCounters.initial_changeset(user_account_id))

      assert inserted == %ServerOwnerCounters{
               __meta__: loaded(ServerOwnerCounters, "server_owner_counters"),
               user_account_id: user_account_id,
               server_count: 1,
               server_count_lock: 1,
               active_server_count: 0,
               active_server_count_lock: 1
             }
    end
  end

  describe "database constraints" do
    test "rejects a negative active-server count" do
      %{id: user_account_id} = AccountsFactory.insert(:user_account, root: true)

      assert_raise Ecto.ConstraintError, ~r/active_server_count_is_not_negative/, fn ->
        insert_counters!(user_account_id, server_count: 0, active_server_count: -1)
      end
    end

    test "rejects an active count greater than the server count" do
      %{id: user_account_id} = AccountsFactory.insert(:user_account, root: true)

      assert_raise Ecto.ConstraintError,
                   ~r/active_server_count_is_not_greater_than_server_count/,
                   fn ->
                     insert_counters!(user_account_id, server_count: 0, active_server_count: 1)
                   end
    end

    test "rejects a non-positive server-count lock" do
      %{id: user_account_id} = AccountsFactory.insert(:user_account, root: true)

      assert_raise Ecto.ConstraintError, ~r/server_count_lock_is_positive/, fn ->
        insert_counters!(user_account_id,
          server_count: 0,
          active_server_count: 0,
          server_count_lock: 0
        )
      end
    end
  end

  defp insert_counters!(user_account_id, attrs) do
    Repo.insert!(%ServerOwnerCounters{
      user_account_id: user_account_id,
      server_count: Keyword.fetch!(attrs, :server_count),
      server_count_lock: Keyword.get(attrs, :server_count_lock, 1),
      active_server_count: Keyword.fetch!(attrs, :active_server_count),
      active_server_count_lock: Keyword.get(attrs, :active_server_count_lock, 1)
    })
  end
end
