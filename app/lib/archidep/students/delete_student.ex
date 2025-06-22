defmodule ArchiDep.Students.DeleteStudent do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.StudentDeleted
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Student

  @spec delete_student(Authentication.t(), UUID.t()) ::
          :ok | {:error, :student_not_found}
  def delete_student(auth, id) do
    with {:ok, student} <- Student.fetch_student(id) do
      authorize!(auth, Policy, :students, :delete_student, student)

      now = DateTime.utc_now()
      user = Authentication.fetch_user_account(auth)

      # TODO: shut down server
      case Multi.new()
           |> Multi.delete(:student, student)
           |> Multi.insert(:stored_event, fn %{student: student} ->
             StudentDeleted.new(student)
             |> new_event(auth, occurred_at: now)
             |> add_to_stream(student)
             |> initiated_by(user)
           end)
           |> Repo.transaction() do
        {:ok, _} ->
          :ok

        {:error, :student, changeset, _} ->
          {:error, changeset}
      end
    end
  end
end
