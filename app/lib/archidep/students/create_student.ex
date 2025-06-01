defmodule ArchiDep.Students.CreateStudent do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.StudentCreated
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types

  @spec validate_student(Authentication.t(), Types.create_student_data()) :: Changeset.t()
  def validate_student(auth, data) do
    authorize!(auth, Policy, :students, :validate_student, nil)
    Student.new(data)
  end

  @spec create_student(Authentication.t(), Types.create_student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()}
  def create_student(auth, data) do
    authorize!(auth, Policy, :students, :create_student, nil)

    user = Authentication.fetch_user_account(auth)

    case Multi.new()
         |> Multi.insert(:student, Student.new(data))
         |> Multi.insert(:stored_event, fn %{student: student} ->
           StudentCreated.new(student)
           |> new_event(auth, occurred_at: student.created_at)
           |> add_to_stream(student)
           |> initiated_by(user)
         end)
         |> Repo.transaction() do
      {:ok, %{student: student}} ->
        {:ok, student}

      {:error, :student, changeset, _} ->
        {:error, changeset}
    end
  end
end
