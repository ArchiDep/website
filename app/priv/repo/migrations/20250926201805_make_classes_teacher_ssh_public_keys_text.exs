defmodule ArchiDep.Repo.Migrations.MakeClassesTeacherSshPublicKeysText do
  use Ecto.Migration

  def change do
    alter table(:classes) do
      modify :teacher_ssh_public_keys, {:array, :text}, null: false
    end
  end
end
