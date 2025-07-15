defmodule ArchiDep.Course.Behaviour do
  use ArchiDep, :behaviour

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types

  @callback validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()

  @callback create_class(Authentication.t(), Types.class_data()) ::
              {:ok, Class.t()} | {:error, Changeset.t()}

  @callback list_classes(Authentication.t()) :: list(Class.t())

  @callback fetch_class(Authentication.t(), UUID.t()) ::
              {:ok, Class.t()} | {:error, :class_not_found}

  @callback validate_existing_class(Authentication.t(), UUID.t(), Types.class_data()) ::
              {:ok, Changeset.t()} | {:error, :class_not_found}

  @callback update_class(Authentication.t(), UUID.t(), Types.class_data()) ::
              {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}

  @callback delete_class(Authentication.t(), UUID.t()) ::
              :ok | {:error, :class_not_found} | {:error, :class_has_servers}

  @callback validate_student(Authentication.t(), Types.create_student_data()) :: Changeset.t()

  @callback create_student(Authentication.t(), Types.create_student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()}

  @callback import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
              {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}

  @callback list_students(Authentication.t(), Class.t()) :: list(Student.t())

  @callback fetch_authenticated_student(Authentication.t()) ::
              {:ok, Student.t()} | {:error, :not_a_student}

  @callback fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
              {:ok, Student.t()} | {:error, :student_not_found}

  @callback validate_existing_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
              {:ok, Changeset.t()} | {:error, :student_not_found}

  @callback update_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()}

  @callback validate_student_config(
              Authentication.t(),
              UUID.t(),
              Types.student_config()
            ) ::
              {:ok, Changeset.t()} | {:error, :student_not_found}

  @callback configure_student(
              Authentication.t(),
              UUID.t(),
              Types.student_config()
            ) ::
              {:ok, Student.t()}
              | {:error, Changeset.t()}
              | {:error, :student_not_found}

  @callback delete_student(Authentication.t(), UUID.t()) ::
              :ok | {:error, :student_not_found}
end
