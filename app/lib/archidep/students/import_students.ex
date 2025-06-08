defmodule ArchiDep.Students.ImportStudents do
  use ArchiDep, :use_case

  import ArchiDep.Events.Store.StoredEvent, only: [to_insert_data: 1]
  alias ArchiDep.Students.Events.StudentCreated
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
        insert_data = StudentImportList.to_insert_data(import_list, class, now)

        case Multi.new()
             |> Multi.insert_all(
               :students,
               Student,
               insert_data,
               on_conflict: :nothing,
               conflict_target: [:class_id, :email],
               returning: true
             )
             |> Multi.run(:new_students, fn _repo, %{students: {inserted, students}} ->
               # Identify the newly inserted students, omitting any that might
               # already have been inserted in the database with the same email.
               # Any newly inserted student will have one of the IDs generated
               # for the insert all operation. Students with other IDs were
               # already present in the database.
               generated_ids = insert_data |> Enum.map(& &1.id) |> MapSet.new()
               new_students = Enum.filter(students, &MapSet.member?(generated_ids, &1.id))
               ^inserted = length(new_students)

               {:ok, new_students}
             end)
             |> insert_events(auth, user, class, import_list, now)
             |> transaction() do
          {:ok, %{students: students}} ->
            {:ok, students}

          {:error, :students, %Changeset{} = changeset, _changes} ->
            {:error, changeset}
        end
      end
    end
  end

  defp insert_events(multi, auth, user, class, import_list, now) do
    multi
    |> Multi.merge(fn
      %{students: {0, _students}, new_students: []} ->
        Multi.new()

      %{students: {inserted, _students}, new_students: new_students} ->
        Multi.new()
        |> Multi.insert(:students_imported_event, fn %{} ->
          StudentsImported.new(
            class,
            import_list.academic_class,
            inserted
          )
          |> new_event(auth, occurred_at: now)
          |> add_to_stream(class)
          |> initiated_by(user)
        end)
        |> Multi.insert_all(:student_created_events, StoredEvent, fn %{
                                                                       students_imported_event:
                                                                         cause
                                                                     } ->
          Enum.map(new_students, fn student ->
            StudentCreated.new(student)
            |> new_event(auth, occurred_at: now, caused_by: cause)
            |> add_to_stream(student)
            |> initiated_by(user)
            |> Changeset.apply_action!(:insert)
            |> to_insert_data()
          end)
        end)
    end)
  end
end
