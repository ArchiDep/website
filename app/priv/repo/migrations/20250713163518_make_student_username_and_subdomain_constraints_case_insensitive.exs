defmodule ArchiDep.Repo.Migrations.MakeStudentUsernameAndSubdomainConstraintsCaseInsensitive do
  use Ecto.Migration

  def up do
    drop unique_index(:students, [:class_id, :subdomain], name: :students_subdomain_unique)

    drop unique_index(:students, [:class_id, :username],
           name: :students_suggested_username_unique
         )

    drop unique_index(:students, [:class_id, :username], name: :students_username_unique)

    create unique_index(:students, [:class_id, "LOWER(subdomain)"],
             name: :students_subdomain_unique
           )

    create unique_index(:students, [:class_id, "LOWER(suggested_username)"],
             name: :students_suggested_username_unique
           )

    create unique_index(:students, [:class_id, "LOWER(username)"],
             name: :students_username_unique
           )
  end

  def down do
    drop unique_index(:students, [:class_id, "LOWER(subdomain)"],
           name: :students_subdomain_unique
         )

    drop unique_index(:students, [:class_id, "LOWER(suggested_username)"],
           name: :students_suggested_username_unique
         )

    drop unique_index(:students, [:class_id, "LOWER(username)"], name: :students_username_unique)

    create unique_index(:students, [:class_id, :subdomain], name: :students_subdomain_unique)

    create unique_index(:students, [:class_id, :suggested_username],
             name: :students_suggested_username_unique
           )

    create unique_index(:students, [:class_id, :username], name: :students_username_unique)
  end
end
