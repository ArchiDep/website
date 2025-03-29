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

  @callback validate_student(Authentication.t(), Types.student_data()) :: Changeset.t()

  @callback create_student(Authentication.t(), Types.student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()}

  @callback list_students(Authentication.t(), Class.t()) :: list(Student.t())
end
