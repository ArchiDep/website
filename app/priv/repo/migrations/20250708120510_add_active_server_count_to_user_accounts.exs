defmodule ArchiDep.Repo.Migrations.AddActiveServerCountToUserAccounts do
  use Ecto.Migration

  def change do
    alter table(:user_accounts) do
      add :active_server_count, :integer, default: 0, null: false
      add :active_server_count_lock, :bigint, default: 1, null: false
    end

    create constraint(:user_accounts, :active_server_count_lock_is_positive,
             check: "active_server_count_lock >= 1"
           )
  end
end
