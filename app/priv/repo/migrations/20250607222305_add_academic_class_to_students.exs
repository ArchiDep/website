defmodule ArchiDep.Repo.Migrations.AddAcademicClassToStudents do
  use Ecto.Migration

  def change do
    alter table(:students) do
      add :academic_class, :string, size: 30, null: true, after: :email
    end
  end
end
