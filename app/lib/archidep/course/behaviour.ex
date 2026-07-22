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
  @callback validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()

  @doc """
  Creates a new class.
  """
  @callback create_class(Authentication.t(), Types.class_data()) ::
              {:ok, Class.t()} | {:error, Changeset.t()}

  @doc """
  Lists all classes.
  """
  @callback list_classes(Authentication.t()) :: list(Class.t())

  @doc """
  Lists currently active classes.
  """
  @callback list_active_classes(Authentication.t()) :: list(Class.t())

  @doc """
  Subscribes the calling process to every topic that keeps the list of classes
  live.
  """
  @callback subscribe_classes() :: :ok

  @doc """
  Reconciles the list of classes from a PubSub message broadcast on one of the
  topics of `subscribe_classes/0`, returning the updated list or `:ignore` for a
  message that does not concern it.
  """
  @callback refresh_classes(list(Class.t()), term()) ::
              {:ok, list(Class.t())} | :ignore

  @doc """
  Fetches a class.
  """
  @callback fetch_class(Authentication.t() | nil, UUID.t()) ::
              {:ok, Class.t()} | {:error, :class_not_found}

  @doc """
  Subscribes the calling process to every topic that keeps the given class's
  read-model live.
  """
  @callback subscribe_class(Class.t()) :: :ok

  @doc """
  Reconciles a class read-model from a PubSub message broadcast on one of the
  topics of `subscribe_class/1`, returning the updated class or `:ignore` for a
  message that does not concern it.
  """
  @callback refresh_class(Class.t() | nil, term()) :: {:ok, Class.t()} | :ignore

  @doc """
  Validates the data to update an existing class.
  """
  @callback validate_existing_class(Authentication.t(), UUID.t(), Types.class_data()) ::
              {:ok, Changeset.t()} | {:error, :class_not_found}

  @doc """
  Updates the specified class with the given data.
  """
  @callback update_class(Authentication.t(), UUID.t(), Types.class_data()) ::
              {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}

  @doc """
  Validates the expected server properties of a class.
  """
  @callback validate_expected_server_properties_for_class(
              Authentication.t(),
              UUID.t(),
              Types.expected_server_properties()
            ) ::
              {:ok, Changeset.t()}
              | {:error, :class_not_found}

  @doc """
  Updates the expected properties of a server group.
  """
  @callback update_expected_server_properties_for_class(
              Authentication.t(),
              UUID.t(),
              Types.expected_server_properties()
            ) ::
              {:ok, ExpectedServerProperties.t()}
              | {:error, Changeset.t()}
              | {:error, :class_not_found}

  @doc """
  Deletes the specified class. The class must not have any servers associated
  with it.
  """
  @callback delete_class(Authentication.t(), UUID.t()) ::
              :ok | {:error, :class_not_found} | {:error, :class_has_servers}

  @doc """
  Validates the data to create a new student.
  """
  @callback validate_student(Authentication.t(), UUID.t(), Types.student_data()) ::
              {:ok, Changeset.t()} | {:error, :class_not_found}

  @doc """
  Creates a new student with the specified data.
  """
  @callback create_student(Authentication.t(), UUID.t(), Types.student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :class_not_found}

  @doc """
  Imports a batch of students into a class.
  """
  @callback import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
              {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}

  @doc """
  Lists all students in the specified class.
  """
  @callback list_students(Authentication.t(), Class.t()) :: list(Student.t())

  @doc """
  Subscribes the calling process to every topic that keeps the list of students
  in the given class live.
  """
  @callback subscribe_class_students(Class.t()) :: :ok

  @doc """
  Reconciles the list of students in a class from a PubSub message broadcast on
  one of the topics of `subscribe_class_students/1`, returning the refreshed
  list or `:ignore` for a message that does not concern it.
  """
  @callback refresh_class_students(Authentication.t(), Class.t(), list(Student.t()), term()) ::
              {:ok, list(Student.t())} | :ignore

  @doc """
  Fetches the student who is currently authenticated.
  """
  @callback fetch_authenticated_student(Authentication.t()) ::
              {:ok, Student.t()} | {:error, :not_a_student}

  @doc """
  Fetches a student in the given class. If the student exists but is in another
  class, it will not be found.
  """
  @callback fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
              {:ok, Student.t()} | {:error, :student_not_found}

  @doc """
  Validates the data to update an existing student.
  """
  @callback validate_existing_student(Authentication.t(), UUID.t(), Types.student_data()) ::
              {:ok, Changeset.t()} | {:error, :student_not_found}

  @doc """
  Updates the specified student with the given data.
  """
  @callback update_student(Authentication.t(), UUID.t(), Types.student_data()) ::
              {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :student_not_found}

  @doc """
  Validates the data to configure a student.
  """
  @callback validate_student_config(Authentication.t(), UUID.t(), Types.student_config()) ::
              {:ok, Changeset.t()} | {:error, :student_not_found}

  @doc """
  Configures the specified student. Whereas `update_student/3` updates the whole
  student, this only updates the configuration accessible to the student.
  """
  @callback configure_student(Authentication.t(), UUID.t(), Types.student_config()) ::
              {:ok, Student.t()}
              | {:error, Changeset.t()}
              | {:error, :student_not_found}

  @doc """
  Deletes the specified student. Note that any user account associated with the
  student will lose its access.
  """
  @callback delete_student(Authentication.t(), UUID.t()) ::
              :ok | {:error, :student_not_found}

  @doc """
  Subscribes the calling process to every topic that keeps the given student's
  read-model live.
  """
  @callback subscribe_student(Student.t()) :: :ok

  @doc """
  Reconciles a student read-model from a PubSub message broadcast on one of the
  topics of `subscribe_student/1`, returning the updated student or `:ignore`
  for a message that does not concern it.
  """
  @callback refresh_student(Student.t() | nil, term()) :: {:ok, Student.t()} | :ignore

  @doc """
  Subscribes the calling process to every topic that keeps a student detail
  read-model — the student, its nested class and its account linkage — live.
  """
  @callback subscribe_student_detail(Student.t()) :: :ok

  @doc """
  Reconciles a student detail read-model (the student and its nested class) from
  a PubSub message broadcast on one of the topics of
  `subscribe_student_detail/1`, returning the updated student or `:ignore` for a
  message that does not concern it.
  """
  @callback refresh_student_detail(Student.t() | nil, term()) :: {:ok, Student.t()} | :ignore
end
