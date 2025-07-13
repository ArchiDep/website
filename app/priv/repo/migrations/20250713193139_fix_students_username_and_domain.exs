defmodule ArchiDep.Repo.Migrations.FixStudentsUsernameAndDomain do
  use Ecto.Migration

  def up do
    execute "UPDATE students SET username = suggested_username WHERE username IS NULL;"

    alter table(:students) do
      modify :username, :string, size: 20, null: false, from: {:string, size: 20, null: true}
      remove :subdomain, :string, size: 20, null: true
      add :username_confirmed, :boolean, null: true
    end

    execute "UPDATE students SET username_confirmed = false;"

    alter table(:students) do
      modify :username_confirmed, :boolean, null: false
    end
  end

  def down do
    alter table(:students) do
      modify :username, :string, size: 20, null: true, from: {:string, size: 20, null: false}
      add :subdomain, :string, size: 20, null: true
      remove :username_confirmed
    end

    create unique_index(:students, [:class_id, "LOWER(subdomain)"],
             name: :students_subdomain_unique
           )
  end
end
