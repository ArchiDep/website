defmodule ArchiDep.Repo.Migrations.AddClassToUserAccountsAndServers do
  use Ecto.Migration

  def change do
    alter table(:user_accounts) do
      add :class_id,
          references(:classes,
            type: :binary_id,
            on_delete: :restrict,
            on_update: :update_all
          ),
          null: true
    end

    alter table(:servers) do
      add :class_id,
          references(:classes,
            type: :binary_id,
            on_delete: :restrict,
            on_update: :update_all
          ),
          null: false
    end
  end
end
