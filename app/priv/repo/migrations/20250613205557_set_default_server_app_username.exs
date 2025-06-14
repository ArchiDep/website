defmodule ArchiDep.Repo.Migrations.SetDefaultServerAppUsername do
  use Ecto.Migration

  def up do
    execute("UPDATE servers SET app_username = 'archidep' WHERE app_username IS NULL")

    alter table(:servers) do
      modify :app_username, :string, null: false
    end
  end

  def down do
    alter table(:servers) do
      modify :app_username, :string, null: true
    end
  end
end
