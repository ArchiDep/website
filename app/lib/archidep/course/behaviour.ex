defmodule ArchiDep.Course.Behaviour do
  @moduledoc false

  use ArchiDep, :context_behaviour

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Types

  @doc """
  Validates the data to create a new class.
  """
  callback(validate_class(auth: Authentication.t(), data: Types.class_data()) :: Changeset.t())

  @doc """
  Creates a new class.
  """
  callback(
    create_class(auth: Authentication.t(), data: Types.class_data()) ::
      {:ok, Class.t()} | {:error, Changeset.t()}
  )

  @doc """
  Lists all classes.
  """
  callback(list_classes(auth: Authentication.t()) :: list(Class.t()))

  @doc """
  Fetches a class.
  """
  callback(
    fetch_class(auth: Authentication.t(), class_id: UUID.t()) ::
      {:ok, Class.t()} | {:error, :class_not_found}
  )

  @doc """
  Validates the data to update an existing class.
  """
  callback(
    validate_existing_class(
      auth: Authentication.t(),
      class_id: UUID.t(),
      data: Types.class_data()
    ) ::
      {:ok, Changeset.t()} | {:error, :class_not_found}
  )

  @doc """
  Updates the specified class with the given data.
  """
  callback(
    update_class(auth: Authentication.t(), class_id: UUID.t(), data: Types.class_data()) ::
      {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  )

  @doc """
  Validates the expected server properties of a class.
  """
  callback(
    validate_expected_server_properties_for_class(
      auth: Authentication.t(),
      class_id: UUID.t(),
      data: Types.expected_server_properties()
    ) ::
      {:ok, Changeset.t()}
      | {:error, :class_not_found}
  )

  @doc """
  Updates the expected properties of a server group.
  """
  callback(
    update_expected_server_properties_for_class(
      auth: Authentication.t(),
      class_id: UUID.t(),
      data: Types.expected_server_properties()
    ) ::
      {:ok, ExpectedServerProperties.t()}
      | {:error, Changeset.t()}
      | {:error, :class_not_found}
  )

  @doc """
  Deletes the specified class. The class must not have any servers associated
  with it.
  """
  callback(
    delete_class(auth: Authentication.t(), class_id: UUID.t()) ::
      :ok | {:error, :class_not_found} | {:error, :class_has_servers}
  )

  @doc """
  Validates the data to create a new student.
  """
  callback(
    validate_student(auth: Authentication.t(), data: Types.create_student_data()) :: Changeset.t()
  )

  @doc """
  Creates a new student with the specified data.
  """
  callback(
    create_student(auth: Authentication.t(), data: Types.create_student_data()) ::
      {:ok, Student.t()} | {:error, Changeset.t()}
  )

  @doc """
  Imports a batch of students into a class.
  """
  callback(
    import_students(
      auth: Authentication.t(),
      class_id: UUID.t(),
      data: Types.import_students_data()
    ) ::
      {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}
  )

  @doc """
  Lists all students in the specified class.
  """
  callback(list_students(auth: Authentication.t(), class: Class.t()) :: list(Student.t()))

  @doc """
  Fetches the student who is currently authenticated.
  """
  callback(
    fetch_authenticated_student(auth: Authentication.t()) ::
      {:ok, Student.t()} | {:error, :not_a_student}
  )

  @doc """
  Fetches a student in the given class. If the student exists but is in another
  class, it will not be found.
  """
  callback(
    fetch_student_in_class(auth: Authentication.t(), class_id: UUID.t(), student_id: UUID.t()) ::
      {:ok, Student.t()} | {:error, :student_not_found}
  )

  @doc """
  Validates the data to update an existing student.
  """
  callback(
    validate_existing_student(
      auth: Authentication.t(),
      student_id: UUID.t(),
      data: Types.existing_student_data()
    ) ::
      {:ok, Changeset.t()} | {:error, :student_not_found}
  )

  @doc """
  Updates the specified student with the given data.
  """
  callback(
    update_student(
      auth: Authentication.t(),
      student_id: UUID.t(),
      data: Types.existing_student_data()
    ) ::
      {:ok, Student.t()} | {:error, Changeset.t()}
  )

  @doc """
  Validates the data to configure a student.
  """
  callback(
    validate_student_config(
      auth: Authentication.t(),
      student_id: UUID.t(),
      data: Types.student_config()
    ) ::
      {:ok, Changeset.t()} | {:error, :student_not_found}
  )

  @doc """
  Configures the specified student. Whereas `update_student/3` updates the whole
  student, this only updates the configuration accessible to the student.
  """
  callback(
    configure_student(
      auth: Authentication.t(),
      student_id: UUID.t(),
      data: Types.student_config()
    ) ::
      {:ok, Student.t()}
      | {:error, Changeset.t()}
      | {:error, :student_not_found}
  )

  @doc """
  Deletes the specified student. Note that any user account associated with the
  student will lose its access.
  """
  callback(
    delete_student(auth: Authentication.t(), student_id: UUID.t()) ::
      :ok | {:error, :student_not_found}
  )
end
