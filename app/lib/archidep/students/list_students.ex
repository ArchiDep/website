defmodule ArchiDep.Students.ListStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :students, :list_students, class)

    class_id = class.id
    Repo.all(from s in Student, where: s.class_id == ^class_id, order_by: s.name)
  end
end
