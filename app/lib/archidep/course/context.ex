defmodule ArchiDep.Course.Context do
  use ArchiDep, :context

  alias ArchiDep.Course.ConfigureStudent
  alias ArchiDep.Course.CreateClass
  alias ArchiDep.Course.CreateStudent
  alias ArchiDep.Course.DeleteClass
  alias ArchiDep.Course.DeleteStudent
  alias ArchiDep.Course.ImportStudents
  alias ArchiDep.Course.ReadClasses
  alias ArchiDep.Course.ReadStudents
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types
  alias ArchiDep.Course.UpdateClass
  alias ArchiDep.Course.UpdateStudent

  @behaviour ArchiDep.Course.Behaviour

  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  defdelegate validate_class(auth, data), to: CreateClass

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data), to: CreateClass

  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: ReadClasses

  @spec fetch_class(Authentication.t(), UUID.t()) :: {:ok, Class.t()} | {:error, :class_not_found}
  defdelegate fetch_class(auth, id), to: ReadClasses

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
          :ok | {:error, :class_not_found} | {:error, :class_has_servers}
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
  defdelegate list_students(auth, class), to: ReadStudents

  @spec fetch_authenticated_student(Authentication.t()) ::
          {:ok, Student.t()} | {:error, :not_a_student}
  defdelegate fetch_authenticated_student(auth), to: ReadStudents

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  defdelegate fetch_student_in_class(auth, class_id, id), to: ReadStudents

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

  @spec validate_student_config(
          Authentication.t(),
          UUID.t(),
          Types.student_config()
        ) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  defdelegate validate_student_config(auth, id, data), to: ConfigureStudent

  @spec configure_student(
          Authentication.t(),
          UUID.t(),
          Types.student_config()
        ) ::
          {:ok, Student.t()}
          | {:error, Changeset.t()}
          | {:error, :student_not_found}
  defdelegate configure_student(auth, id, data), to: ConfigureStudent

  @spec delete_student(Authentication.t(), UUID.t()) ::
          :ok | {:error, :student_not_found}
  defdelegate delete_student(auth, id), to: DeleteStudent
end
