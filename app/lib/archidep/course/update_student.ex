defmodule ArchiDep.Course.UpdateStudent do
  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types

  @spec validate_existing_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  def validate_existing_student(auth, id, data) do
    with :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :course, :validate_existing_student, student)
      {:ok, Student.update(student, data)}
    end
  end

  @spec update_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :student_not_found}
  def update_student(auth, id, data) do
    with :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :course, :update_student, student)

      case Multi.new()
           |> Multi.update(:student, Student.update(student, data))
           |> Multi.insert(:stored_event, fn %{student: student} ->
             StudentUpdated.new(student)
             |> new_event(auth, occurred_at: student.updated_at)
             |> add_to_stream(student)
             |> initiated_by(auth)
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
