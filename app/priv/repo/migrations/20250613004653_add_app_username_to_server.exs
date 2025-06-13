defmodule ArchiDep.Repo.Migrations.AddAppUsernameToServer do
  use Ecto.Migration

  def change do
    alter table(:servers) do
      add :app_username, :string, null: true
    end
  end
end
