defmodule ArchiDep.Repo.Migrations.AddSuggestedUsernameToStudents do
  use Ecto.Migration

  def up do
    alter table(:students) do
      add :suggested_username, :string, size: 10, null: true
      add :username, :string, size: 10, null: true
    end

    execute "UPDATE students SET suggested_username = substr(md5(random()::text), 1, 5);"

    alter table(:students) do
      modify :suggested_username, :string, size: 10, null: false
    end

    create unique_index(:students, [:class_id, :suggested_username],
             name: :students_suggested_username_unique
           )

    create unique_index(:students, [:class_id, :username], name: :students_username_unique)
  end

  def down do
    alter table(:students) do
      remove :suggested_username
      remove :username
    end
  end
end
