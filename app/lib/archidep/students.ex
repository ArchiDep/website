defmodule ArchiDep.Students do
  use ArchiDep, :context

  @behaviour ArchiDep.Students.Behaviour

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  defdelegate validate_class(auth, data), to: @implementation

  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data), to: @implementation

  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: @implementation

  @spec fetch_class(Authentication.t(), UUID.t()) :: {:ok, Class.t()} | {:error, :class_not_found}
  defdelegate fetch_class(auth, id), to: @implementation

  @spec validate_existing_class(
          Authentication.t(),
          UUID.t(),
          Types.class_data()
        ) :: {:ok, Changeset.t()} | {:error, :class_not_found}
  defdelegate validate_existing_class(auth, id, data), to: @implementation

  @spec update_class(
          Authentication.t(),
          UUID.t(),
          Types.class_data()
        ) :: {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate update_class(auth, id, data), to: @implementation

  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found}
  defdelegate delete_class(auth, id), to: @implementation

  @spec validate_student(Authentication.t(), Types.student_data()) :: Changeset.t()
  defdelegate validate_student(auth, data), to: @implementation

  @spec create_student(Authentication.t(), Types.student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()}
  defdelegate create_student(auth, data), to: @implementation

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  defdelegate list_students(auth, class), to: @implementation

  @spec list_active_students_for_email(String.t()) :: list(Student.t())
  defdelegate list_active_students_for_email(email), to: @implementation

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  defdelegate fetch_student_in_class(auth, class_id, id), to: @implementation
end
