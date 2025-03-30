defmodule ArchiDep.Students.ListStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :students, :list_students, class)

    class_id = class.id

    Repo.all(
      from s in Student,
        left_join: ua in UserAccount,
        on: s.user_account_id == ua.id,
        where: s.class_id == ^class_id,
        order_by: s.name,
        preload: [user_account: ua]
    )
  end

  @spec list_active_students_for_email(String.t()) :: list(Student.t())
  def list_active_students_for_email(email) do
    from(s in Student,
      join: c in Class,
      on: s.class_id == c.id,
      where:
        c.active and is_nil(s.user_account_id) and
          fragment("LOWER(?)", s.email) == fragment("LOWER(?)", ^email),
      preload: [class: c]
    )
    |> Repo.all()
  end
end
