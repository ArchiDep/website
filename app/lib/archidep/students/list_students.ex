defmodule ArchiDep.Students.ListStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :students, :list_students, class)

    class_id = class.id

    Repo.all(
      from s in Student,
        left_join: ua in assoc(s, :user_account),
        where: s.class_id == ^class_id,
        order_by: s.name,
        preload: [user_account: ua]
    )
  end

  @spec list_active_students_for_email(String.t(), DateTime.t()) :: list(Student.t())
  def list_active_students_for_email(email, now) do
    from(s in Student,
      join: c in assoc(s, :class),
      # TODO: extract class active check to a function in the Class schema
      where:
        s.active and
          c.active and (is_nil(c.start_date) or c.start_date <= ^now) and
          (is_nil(c.end_date) or c.end_date >= ^now) and is_nil(s.user_account_id) and
          fragment("LOWER(?)", s.email) == fragment("LOWER(?)", ^email),
      preload: [class: c]
    )
    |> Repo.all()
  end
end
