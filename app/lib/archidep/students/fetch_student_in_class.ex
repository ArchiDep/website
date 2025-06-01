defmodule ArchiDep.Students.FetchStudentInClass do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Student

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  def fetch_student_in_class(auth, class_id, id) do
    with {:ok, student} <- Student.fetch_student_in_class(class_id, id),
         :ok <- authorize(auth, Policy, :students, :fetch_student_in_class, student) do
      {:ok, student}
    else
      {:error, {:access_denied, :students, :fetch_student_in_class}} ->
        {:error, :student_not_found}
    end
  end
end
