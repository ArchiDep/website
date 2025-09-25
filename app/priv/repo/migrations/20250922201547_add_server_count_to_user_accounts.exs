defmodule ArchiDep.Repo.Migrations.AddServerCountToUserAccounts do
  use Ecto.Migration

  def change do
    alter table(:user_accounts) do
      add :server_count, :integer, default: 0, null: false
      add :server_count_lock, :bigint, default: 1, null: false
    end

    create constraint(:user_accounts, :active_server_count_is_not_negative,
             check: "active_server_count >= 0"
           )

    create constraint(:user_accounts, :server_count_is_not_negative, check: "server_count >= 0")

    create constraint(:user_accounts, :server_count_lock_is_positive,
             check: "server_count_lock >= 1"
           )

    execute(
      """
      WITH server_counts AS (
        SELECT user_account_id, count(*) AS cnt
        FROM servers
        GROUP BY user_account_id
      )
      UPDATE user_accounts ua
      SET server_count = sc.cnt
      FROM server_counts sc
      WHERE ua.id = sc.user_account_id;
      """,
      "SELECT 1;"
    )

    create constraint(:user_accounts, :active_server_count_is_not_greater_than_server_count,
             check: "active_server_count <= server_count"
           )
  end
end
