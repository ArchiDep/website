defmodule ArchiDep.Students.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Students.CreateClass
  alias ArchiDep.Students.CreateStudent
  alias ArchiDep.Students.FetchClass
  alias ArchiDep.Students.ListClasses
  alias ArchiDep.Students.ListStudents
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types
  alias ArchiDep.Students.UpdateClass

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

  @spec validate_student(Authentication.t(), Types.student_data()) :: Changeset.t()
  defdelegate validate_student(auth, data), to: CreateStudent

  @spec create_student(Authentication.t(), Types.student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()}
  defdelegate create_student(auth, data), to: CreateStudent

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  defdelegate list_students(auth, class), to: ListStudents

  @spec list_active_students_for_email(String.t()) :: list(Student.t())
  defdelegate list_active_students_for_email(email), to: ListStudents
end
