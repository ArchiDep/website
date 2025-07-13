defmodule ArchiDep.Course.ReadStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :course, :list_students, class)

    class_id = class.id

    Repo.all(
      from s in Student,
        join: c in assoc(s, :class),
        left_join: u in assoc(s, :user),
        left_join: us in assoc(u, :student),
        left_join: usc in assoc(us, :class),
        where: s.class_id == ^class_id,
        order_by: s.name,
        preload: [class: c, user: {u, student: {us, class: usc}}]
    )
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
