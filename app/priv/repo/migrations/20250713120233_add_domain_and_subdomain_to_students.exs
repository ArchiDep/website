defmodule ArchiDep.Repo.Migrations.AddDomainAndSubdomainToStudents do
  use Ecto.Migration

  def up do
    alter table(:students) do
      add :domain, :string, size: 20, null: true
      add :subdomain, :string, size: 20, null: true
    end

    execute "UPDATE students SET domain = 'archidep.ch';"

    alter table(:students) do
      modify :domain, :string, size: 20, null: false
      modify :suggested_username, :string, size: 20, null: false
      modify :username, :string, size: 20, null: true
    end

    create unique_index(:students, [:class_id, :subdomain], name: :students_subdomain_unique)
  end

  def down do
    alter table(:students) do
      remove :domain
      remove :subdomain
      modify :suggested_username, :string, size: 10, null: false
      modify :username, :string, size: 10, null: true
    end
  end
end
