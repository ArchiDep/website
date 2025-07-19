defmodule ArchiDep.Course.UseCases.DeleteStudent do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Course.Events.StudentDeleted
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Student

  @spec delete_student(Authentication.t(), UUID.t()) ::
          :ok | {:error, :student_not_found}
  def delete_student(auth, id) do
    with :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :course, :delete_student, student)

      now = DateTime.utc_now()

      # TODO: shut down server
      case Multi.new()
           |> Multi.delete(:student, student)
           |> Multi.insert(:stored_event, &student_deleted(auth, &1.student, now))
           |> Repo.transaction() do
        {:ok, _changes} ->
          :ok = PubSub.publish_student_deleted(student)
          :ok

        {:error, :student, changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  defp student_deleted(auth, student, now),
    do:
      student
      |> StudentDeleted.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(student)
      |> initiated_by(auth)
end
