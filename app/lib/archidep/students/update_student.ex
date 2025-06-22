defmodule ArchiDep.Students.UpdateStudent do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.StudentUpdated
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types

  @spec validate_existing_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  def validate_existing_student(auth, id, data) do
    with {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :students, :validate_existing_student, student)
      {:ok, Student.update(student, data)}
    end
  end

  @spec update_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :student_not_found}
  def update_student(auth, id, data) do
    with {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :students, :update_student, student)

      user = Authentication.fetch_user_account(auth)

      case Multi.new()
           |> Multi.update(:student, Student.update(student, data))
           |> Multi.insert(:stored_event, fn %{student: student} ->
             StudentUpdated.new(student)
             |> new_event(auth, occurred_at: student.updated_at)
             |> add_to_stream(student)
             |> initiated_by(user)
           end)
           |> Repo.transaction() do
        {:ok, %{student: student}} ->
          :ok = PubSub.publish_student(student)
          {:ok, student}

        {:error, :student, changeset, _} ->
          {:error, changeset}
      end
    end
  end
end
