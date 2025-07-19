defmodule ArchiDep.Course.UseCases.ConfigureStudent do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Course.Types

  @spec validate_student_config(
          Authentication.t(),
          UUID.t(),
          Types.student_config()
        ) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  def validate_student_config(auth, id, data) do
    with :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student(id),
         {:ok, user} <- User.fetch_authenticated(auth),
         :ok <- authorize(auth, Policy, :course, :configure_student, {user, student}) do
      {:ok, Student.configure_changeset(student, data)}
    else
      {:error, :student_not_found} ->
        {:error, :student_not_found}

      {:error, :not_a_user} ->
        {:error, :student_not_found}

      {:error, {:access_denied, :course, :configure_student}} ->
        {:error, :student_not_found}
    end
  end

  @spec configure_student(
          Authentication.t(),
          UUID.t(),
          Types.student_config()
        ) ::
          {:ok, Student.t()}
          | {:error, Changeset.t()}
          | {:error, :student_not_found}
  def configure_student(auth, id, data) do
    with :ok <- validate_uuid(id, :student_not_found),
         {:ok, user} = User.fetch_authenticated(auth),
         {:ok, student} <- Student.fetch_student(id),
         :ok <-
           authorize(auth, Policy, :course, :configure_student, {user, student}),
         {:ok, updated_student} <- transaction(auth, student, data) do
      :ok = PubSub.publish_student_updated(updated_student)
      {:ok, updated_student}
    else
      {:error, :student_not_found} ->
        {:error, :student_not_found}

      {:error, :not_a_user} ->
        {:error, :student_not_found}

      {:error, {:access_denied, :course, :configure_student}} ->
        {:error, :student_not_found}

      {:error, %Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  defp transaction(auth, student, data) do
    case Multi.new()
         |> Multi.update(:student, Student.configure_changeset(student, data))
         |> Multi.insert(:stored_event, &student_configured(auth, &1.student))
         |> Repo.transaction() do
      {:ok, %{student: updated_student}} ->
        {:ok, updated_student}

      {:error, :student, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp student_configured(auth, student),
    do:
      student
      |> StudentConfigured.new()
      |> new_event(auth, occurred_at: student.updated_at)
      |> add_to_stream(student)
      |> initiated_by(auth)
end
