defmodule ArchiDep.Repo.Migrations.AddImpersonate do
  use Ecto.Migration

  def change do
    alter table(:user_sessions) do
      add(
        :impersonated_user_account_id,
        references(:user_accounts,
          type: :binary_id,
          on_delete: :nilify_all,
          on_update: :update_all
        )
      )
    end
  end
end
