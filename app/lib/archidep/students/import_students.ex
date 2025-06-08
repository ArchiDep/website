defmodule ArchiDep.Students.ImportStudents do
  use ArchiDep, :use_case

  alias ArchiDep.Students.Events.StudentsImported
  alias ArchiDep.Students.Policy
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Schemas.StudentImportList
  alias ArchiDep.Students.Types

  @spec import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
          {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}
  def import_students(auth, class_id, data) do
    with {:ok, class} <- Class.fetch_class(class_id) do
      authorize!(auth, Policy, :students, :import_students, class)
      user = Authentication.fetch_user_account(auth)

      now = DateTime.utc_now()
      changeset = StudentImportList.changeset(data)

      with {:ok, import_list} <- Changeset.apply_action(changeset, :validate) do
        case Multi.new()
             |> Multi.insert_all(
               :students,
               Student,
               StudentImportList.to_insert_data(import_list, class, now),
               on_conflict: :nothing,
               conflict_target: [:class_id, :email],
               returning: true
             )
             |> Multi.insert(:stored_event, fn %{students: students} ->
               new_students = Enum.filter(students, & &1.id)

               StudentsImported.new(
                 class,
                 import_list.academic_class,
                 new_students
               )
               |> new_event(auth, occurred_at: now)
               |> add_to_stream(class)
               |> initiated_by(user)
             end)
             |> transaction() do
          {:ok, %{students: students}} ->
            {:ok, students}

          {:error, :students, %Changeset{} = changeset, _changes} ->
            {:error, changeset}
        end
      end
    end
  end
end
