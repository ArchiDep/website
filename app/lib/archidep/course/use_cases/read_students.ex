defmodule ArchiDep.Course.UseCases.ReadStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :course, :list_students, class)
    Student.list_students_in_class(class.id)
  end

  @spec fetch_authenticated_student(Authentication.t()) ::
          {:ok, Student.t()} | {:error, :not_a_student}
  def fetch_authenticated_student(auth) do
    with {:ok, student} <-
           auth |> Authentication.principal_id() |> Student.fetch_student_for_user_account_id(),
         :ok <- authorize(auth, Policy, :course, :fetch_authenticated_student, student) do
      {:ok, student}
    else
      {:error, :student_not_found} ->
        {:error, :not_a_student}

      {:error, {:access_denied, :course, :fetch_authenticated_student}} ->
        {:error, :not_a_student}
    end
  end

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  def fetch_student_in_class(auth, class_id, id) do
    with :ok <- validate_uuid(class_id, :student_not_found),
         :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student_in_class(class_id, id),
         :ok <- authorize(auth, Policy, :course, :fetch_student_in_class, student) do
      {:ok, student}
    else
      {:error, :student_not_found} ->
        {:error, :student_not_found}

      {:error, {:access_denied, :course, :fetch_student_in_class}} ->
        {:error, :student_not_found}
    end
  end
end
