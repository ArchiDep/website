defmodule ArchiDep.Course.UseCases.CreateStudent do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.StudentCreated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types

  @spec validate_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Changeset.t()} | {:error, :class_not_found}
  def validate_student(auth, class_id, data) do
    with :ok <- validate_uuid(class_id, :class_not_found),
         {:ok, class} <- Class.fetch_class(class_id),
         :ok <- authorize(auth, Policy, :course, :validate_student, class) do
      {:ok, Student.new(data, class)}
    else
      {:error, {:access_denied, :course, :validate_student}} ->
        {:error, :class_not_found}

      {:error, :class_not_found} ->
        {:error, :class_not_found}
    end
  end

  @spec create_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  def create_student(auth, class_id, data) do
    with :ok <- validate_uuid(class_id, :class_not_found),
         {:ok, class} <- Class.fetch_class(class_id),
         :ok <- authorize(auth, Policy, :course, :create_student, class) do
      case Multi.new()
           |> Multi.insert(:student, Student.new(data, class))
           |> Multi.insert(:stored_event, &student_created(auth, &1.student))
           |> transaction() do
        {:ok, %{student: student}} ->
          :ok = PubSub.publish_student_created(student)
          {:ok, student}

        {:error, :student, changeset, _changes} ->
          {:error, changeset}
      end
    else
      {:error, {:access_denied, :course, :validate_student}} ->
        {:error, :class_not_found}

      {:error, :class_not_found} ->
        {:error, :class_not_found}
    end
  end

  defp student_created(auth, student),
    do:
      student
      |> StudentCreated.new()
      |> new_event(auth, occurred_at: student.created_at)
      |> add_to_stream(student)
      |> initiated_by(auth)
end
