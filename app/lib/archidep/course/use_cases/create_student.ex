defmodule ArchiDep.Course.UseCases.CreateStudent do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.StudentCreated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types

  @spec validate_student(Authentication.t(), Types.create_student_data()) :: Changeset.t()
  def validate_student(auth, data) do
    authorize!(auth, Policy, :course, :validate_student, nil)
    Student.new(data)
  end

  @spec create_student(Authentication.t(), Types.create_student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()}
  def create_student(auth, data) do
    authorize!(auth, Policy, :course, :create_student, nil)

    case Multi.new()
         |> Multi.insert(:student, Student.new(data))
         |> Multi.insert(:stored_event, fn %{student: student} ->
           StudentCreated.new(student)
           |> new_event(auth, occurred_at: student.created_at)
           |> add_to_stream(student)
           |> initiated_by(auth)
         end)
         |> transaction() do
      {:ok, %{student: student}} ->
        :ok = PubSub.publish_student_created(student)
        {:ok, student}

      {:error, :student, changeset, _changes} ->
        {:error, changeset}
    end
  end
end
