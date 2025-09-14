defmodule ArchiDep.Repo.Migrations.AddRootVsStudentCheckConstraint do
  use Ecto.Migration

  def change do
    # Add a constraint to the user_accounts table to ensure that either the root
    # flag is true, or the account is linked to a preregistered student. Either
    # one or the other must be true, but not both. A user account cannot be both
    # a root user and a student.
    create constraint(
             :user_accounts,
             :user_accounts_root_or_student_check,
             check: "root <> (student_id IS NOT NULL)"
           )
  end
end
