defmodule ArchiDep.Repo.Migrations.MoveServerCountersToServerOwnerCounters do
  use Ecto.Migration

  def up do
    create table(:server_owner_counters, primary_key: false) do
      add :user_account_id,
          references(:user_accounts,
            type: :binary_id,
            on_update: :update_all,
            on_delete: :delete_all
          ),
          primary_key: true

      add :active_server_count, :integer, default: 0, null: false
      add :active_server_count_lock, :bigint, default: 1, null: false
      add :server_count, :integer, default: 0, null: false
      add :server_count_lock, :bigint, default: 1, null: false
    end

    create constraint(:server_owner_counters, :active_server_count_lock_is_positive,
             check: "active_server_count_lock >= 1"
           )

    create constraint(:server_owner_counters, :active_server_count_is_not_negative,
             check: "active_server_count >= 0"
           )

    create constraint(:server_owner_counters, :server_count_is_not_negative,
             check: "server_count >= 0"
           )

    create constraint(:server_owner_counters, :server_count_lock_is_positive,
             check: "server_count_lock >= 1"
           )

    create constraint(
             :server_owner_counters,
             :active_server_count_is_not_greater_than_server_count,
             check: "active_server_count <= server_count"
           )

    execute("""
    INSERT INTO server_owner_counters (
      user_account_id,
      active_server_count,
      active_server_count_lock,
      server_count,
      server_count_lock
    )
    SELECT id, active_server_count, active_server_count_lock, server_count, server_count_lock
    FROM user_accounts;
    """)

    alter table(:user_accounts) do
      remove :active_server_count
      remove :active_server_count_lock
      remove :server_count
      remove :server_count_lock
    end
  end

  def down do
    alter table(:user_accounts) do
      add :active_server_count, :integer, default: 0, null: false
      add :active_server_count_lock, :bigint, default: 1, null: false
      add :server_count, :integer, default: 0, null: false
      add :server_count_lock, :bigint, default: 1, null: false
    end

    execute("""
    UPDATE user_accounts ua
    SET active_server_count = c.active_server_count,
        active_server_count_lock = c.active_server_count_lock,
        server_count = c.server_count,
        server_count_lock = c.server_count_lock
    FROM server_owner_counters c
    WHERE ua.id = c.user_account_id;
    """)

    create constraint(:user_accounts, :active_server_count_lock_is_positive,
             check: "active_server_count_lock >= 1"
           )

    create constraint(:user_accounts, :active_server_count_is_not_negative,
             check: "active_server_count >= 0"
           )

    create constraint(:user_accounts, :server_count_is_not_negative, check: "server_count >= 0")

    create constraint(:user_accounts, :server_count_lock_is_positive,
             check: "server_count_lock >= 1"
           )

    create constraint(:user_accounts, :active_server_count_is_not_greater_than_server_count,
             check: "active_server_count <= server_count"
           )

    drop table(:server_owner_counters)
  end
end
