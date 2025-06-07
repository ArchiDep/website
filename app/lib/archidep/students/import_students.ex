defmodule ArchiDep.Students.ImportStudents do
  use ArchiDep, :use_case

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

      changeset = StudentImportList.changeset(data)

      with {:ok, import_list} <- Changeset.apply_action(changeset, :validate) do
        case Multi.new()
             |> Multi.insert_all(
               :students,
               Student,
               StudentImportList.to_insert_data(import_list, class),
               on_conflict: :nothing,
               conflict_target: [:class_id, :email],
               returning: true
             )
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
