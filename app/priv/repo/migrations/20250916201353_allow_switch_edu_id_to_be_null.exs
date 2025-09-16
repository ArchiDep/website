defmodule ArchiDep.Repo.Migrations.AllowSwitchEduIdToBeNull do
  use Ecto.Migration

  def change do
    alter table(:user_accounts) do
      modify :switch_edu_id_id, :uuid, null: true, from: {:string, null: false}
    end
  end
end
