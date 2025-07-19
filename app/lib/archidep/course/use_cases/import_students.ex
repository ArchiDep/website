defmodule ArchiDep.Course.UseCases.ImportStudents do
  @moduledoc false

  use ArchiDep, :use_case

  import ArchiDep.Events.Store.StoredEvent, only: [to_insert_data: 1]
  alias ArchiDep.Course.Events.StudentCreated
  alias ArchiDep.Course.Events.StudentsImported
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.StudentImportList
  alias ArchiDep.Course.Types

  @spec import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
          {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}
  def import_students(auth, class_id, data) do
    with :ok <- validate_uuid(class_id, :class_not_found),
         {:ok, class} <- Class.fetch_class(class_id) do
      authorize!(auth, Policy, :course, :import_students, class)

      now = DateTime.utc_now()
      changeset = StudentImportList.changeset(data)

      existing_usernames =
        class.id
        |> Student.list_students_in_class()
        |> Enum.map(& &1.username)

      with {:ok, import_list} <- Changeset.apply_action(changeset, :validate) do
        insert_data =
          StudentImportList.to_insert_data(import_list, class, existing_usernames, now)

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
             |> insert_events(auth, class, import_list, now)
             |> transaction() do
          {:ok, %{new_students: new_students}} ->
            :ok = PubSub.publish_students_imported(class, new_students)
            {:ok, new_students}

          {:error, :students, %Changeset{} = changeset, _changes} ->
            {:error, changeset}
        end
      end
    end
  end

  defp insert_events(multi, auth, class, import_list, now),
    do:
      Multi.merge(multi, fn
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
            |> initiated_by(auth)
          end)
          |> Multi.insert_all(:student_created_events, StoredEvent, fn %{
                                                                         students_imported_event:
                                                                           cause
                                                                       } ->
            Enum.map(new_students, &student_created(auth, &1, cause, now))
          end)
      end)

  defp student_created(auth, student, cause, now),
    do:
      StudentCreated.new(student)
      |> new_event(auth, occurred_at: now, caused_by: cause)
      |> add_to_stream(student)
      |> initiated_by(auth)
      |> Changeset.apply_action!(:insert)
      |> to_insert_data()
end
