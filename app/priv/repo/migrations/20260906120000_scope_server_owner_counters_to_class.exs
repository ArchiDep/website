defmodule ArchiDep.Repo.Migrations.ScopeServerOwnerCountersToClass do
  use Ecto.Migration

  # The counts are rebuilt from the servers table rather than split out of the
  # existing rows, because an account-wide count carries no record of which
  # class each of its servers belonged to. The optimistic locks restart at 1;
  # they only serialize concurrent writes and are never compared across
  # restarts.

  def up do
    execute("DELETE FROM server_owner_counters;")

    alter table(:server_owner_counters) do
      add :class_id,
          references(:classes,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :delete_all
          ),
          null: false
    end

    execute("ALTER TABLE server_owner_counters DROP CONSTRAINT server_owner_counters_pkey;")
    execute("ALTER TABLE server_owner_counters ADD PRIMARY KEY (user_account_id, class_id);")

    execute("""
    INSERT INTO server_owner_counters (
      user_account_id,
      class_id,
      active_server_count,
      active_server_count_lock,
      server_count,
      server_count_lock
    )
    SELECT user_account_id, class_id, COUNT(*) FILTER (WHERE active), 1, COUNT(*), 1
    FROM servers
    GROUP BY user_account_id, class_id;
    """)
  end

  def down do
    execute("DELETE FROM server_owner_counters;")

    execute("ALTER TABLE server_owner_counters DROP CONSTRAINT server_owner_counters_pkey;")

    alter table(:server_owner_counters) do
      remove :class_id
    end

    execute("ALTER TABLE server_owner_counters ADD PRIMARY KEY (user_account_id);")

    execute("""
    INSERT INTO server_owner_counters (
      user_account_id,
      active_server_count,
      active_server_count_lock,
      server_count,
      server_count_lock
    )
    SELECT user_account_id, COUNT(*) FILTER (WHERE active), 1, COUNT(*), 1
    FROM servers
    GROUP BY user_account_id;
    """)
  end
end
