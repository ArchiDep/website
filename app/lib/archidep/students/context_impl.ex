defmodule ArchiDep.Students.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Students.CreateClass
  alias ArchiDep.Students.CreateStudent
  alias ArchiDep.Students.DeleteClass
  alias ArchiDep.Students.DeleteStudent
  alias ArchiDep.Students.FetchClass
  alias ArchiDep.Students.FetchStudentInClass
  alias ArchiDep.Students.ImportStudents
  alias ArchiDep.Students.ListClasses
  alias ArchiDep.Students.ListStudents
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types
  alias ArchiDep.Students.UpdateClass
  alias ArchiDep.Students.UpdateStudent

  @behaviour ArchiDep.Students.Behaviour

  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  defdelegate validate_class(auth, data), to: CreateClass

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data), to: CreateClass

  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: ListClasses

  @spec fetch_class(Authentication.t(), UUID.t()) :: {:ok, Class.t()} | {:error, :class_not_found}
  defdelegate fetch_class(auth, id), to: FetchClass

  @spec validate_existing_class(
          Authentication.t(),
          UUID.t(),
          Types.class_data()
        ) :: {:ok, Changeset.t()} | {:error, :class_not_found}
  defdelegate validate_existing_class(auth, id, data), to: UpdateClass

  @spec update_class(
          Authentication.t(),
          UUID.t(),
          Types.class_data()
        ) :: {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate update_class(auth, id, data), to: UpdateClass

  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found}
  defdelegate delete_class(auth, id), to: DeleteClass

  @spec validate_student(Authentication.t(), Types.create_student_data()) :: Changeset.t()
  defdelegate validate_student(auth, data), to: CreateStudent

  @spec create_student(Authentication.t(), Types.create_student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()}
  defdelegate create_student(auth, data), to: CreateStudent

  @spec import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
          {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate import_students(auth, id, data), to: ImportStudents

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  defdelegate list_students(auth, class), to: ListStudents

  @spec list_active_students_for_email(String.t(), DateTime.t()) :: list(Student.t())
  defdelegate list_active_students_for_email(email, now), to: ListStudents

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  defdelegate fetch_student_in_class(auth, class_id, id), to: FetchStudentInClass

  @spec validate_existing_student(
          Authentication.t(),
          UUID.t(),
          Types.existing_student_data()
        ) :: {:ok, Changeset.t()} | {:error, :student_not_found}
  defdelegate validate_existing_student(auth, id, data), to: UpdateStudent

  @spec update_student(
          Authentication.t(),
          UUID.t(),
          Types.existing_student_data()
        ) :: {:ok, Student.t()} | {:error, Changeset.t()}
  defdelegate update_student(auth, id, data), to: UpdateStudent

  @spec delete_student(Authentication.t(), UUID.t()) ::
          :ok | {:error, :student_not_found}
  defdelegate delete_student(auth, id), to: DeleteStudent
end
