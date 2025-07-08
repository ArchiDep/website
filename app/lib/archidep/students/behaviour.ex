defmodule ArchiDep.Students.Behaviour do
  use ArchiDep, :behaviour

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDep.Students.Types

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

  @callback fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
              {:ok, Student.t()} | {:error, :student_not_found}

  @callback validate_existing_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
              {:ok, Changeset.t()} | {:error, :student_not_found}

  @callback update_student(Authentication.t(), UUID.t(), Types.existing_student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()}

  @callback delete_student(Authentication.t(), UUID.t()) ::
              :ok | {:error, :student_not_found}
end
