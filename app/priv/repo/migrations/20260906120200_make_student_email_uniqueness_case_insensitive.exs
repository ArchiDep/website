defmodule ArchiDep.Repo.Migrations.MakeStudentEmailUniquenessCaseInsensitive do
  use Ecto.Migration

  # Email addresses are matched case-insensitively everywhere they are compared:
  # the student changesets, and the login that finds a preregistration by the
  # addresses a Switch edu-ID account carries. But the index that has the final
  # say did not fold case, so the bulk import could still land two rows for one
  # person in a class. The sibling `students_username_unique` has always been
  # `LOWER(username)`; this brings the email in line.
  #
  # Creating the index fails if a class already holds two addresses differing
  # only in case. Postgres names the duplicate in the error; merge the rows by
  # hand and run the migration again.

  def up do
    drop unique_index(:students, [:class_id, :email], name: :students_unique_email_in_class_index)

    create unique_index(:students, [:class_id, "LOWER(email)"],
             name: :students_unique_email_in_class_index
           )
  end

  def down do
    drop unique_index(:students, [:class_id, "LOWER(email)"],
           name: :students_unique_email_in_class_index
         )

    create unique_index(:students, [:class_id, :email],
             name: :students_unique_email_in_class_index
           )
  end
end
