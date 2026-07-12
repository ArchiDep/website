defmodule ArchiDep.Repo.Migrations.AddSchemaVersionToEvents do
  use Ecto.Migration

  def up do
    alter table(:events) do
      add :schema_version, :integer
    end

    execute("UPDATE events SET schema_version = 1")

    alter table(:events) do
      modify :schema_version, :integer, null: false
    end
  end

  def down do
    alter table(:events) do
      remove :schema_version
    end
  end
end
