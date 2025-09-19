defmodule ArchiDep.Repo.Migrations.AddTeacherPublicKeysToClass do
  use Ecto.Migration

  def up do
    alter table(:classes) do
      add :teacher_ssh_public_keys, {:array, :string}
    end

    execute "UPDATE classes SET teacher_ssh_public_keys = ARRAY[]::VARCHAR[]"

    alter table(:classes) do
      modify :teacher_ssh_public_keys, {:array, :string}, null: false
    end
  end

  def down do
    alter table(:classes) do
      remove :teacher_ssh_public_keys
    end
  end
end
