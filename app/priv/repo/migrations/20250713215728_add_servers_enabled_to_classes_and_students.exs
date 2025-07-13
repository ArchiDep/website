defmodule ArchiDep.Repo.Migrations.AddServersEnabledToClassesAndStudents do
  use Ecto.Migration

  def up do
    alter table(:classes) do
      add(:servers_enabled, :boolean, null: true)
    end

    execute "UPDATE classes SET servers_enabled = false WHERE servers_enabled IS NULL;"

    alter table(:classes) do
      modify(:servers_enabled, :boolean, null: false)
    end

    alter table(:students) do
      add(:servers_enabled, :boolean, null: true)
    end

    execute "UPDATE students SET servers_enabled = false WHERE servers_enabled IS NULL;"

    alter table(:students) do
      modify(:servers_enabled, :boolean, null: false)
    end
  end

  def down do
    alter table(:classes) do
      remove(:servers_enabled)
    end

    alter table(:students) do
      remove(:servers_enabled)
    end
  end
end
