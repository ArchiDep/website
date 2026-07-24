defmodule ArchiDep.Course do
  @moduledoc """
  Course context to manage classes and students and all related configuration.
  """

  @behaviour ArchiDep.Course.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Course.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  # Classes

  @doc """
  Validates the data to create a new class.
  """
  @spec validate_class(Authentication.t(), Types.class_data()) :: Changeset.t()
  defdelegate validate_class(auth, data), to: @implementation

  @doc """
  Creates a new class.
  """
  @spec create_class(Authentication.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()}
  defdelegate create_class(auth, data), to: @implementation

  @doc """
  Lists all classes.
  """
  @spec list_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_classes(auth), to: @implementation

  @doc """
  Lists currently active classes.
  """
  @spec list_active_classes(Authentication.t()) :: list(Class.t())
  defdelegate list_active_classes(auth), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the list of classes
  live.
  """
  @spec subscribe_classes() :: :ok
  defdelegate subscribe_classes(), to: @implementation

  @doc """
  Reconciles the list of classes from a PubSub message broadcast on one of the
  topics of `subscribe_classes/0`, returning the updated list or `:ignore` for a
  message that does not concern it.
  """
  @spec refresh_classes(list(Class.t()), term()) ::
          {:ok, list(Class.t())} | :ignore
  defdelegate refresh_classes(classes, message), to: @implementation

  @doc """
  Fetches a class.
  """
  @spec fetch_class(Authentication.t() | nil, UUID.t()) ::
          {:ok, Class.t()} | {:error, :class_not_found}
  defdelegate fetch_class(auth, class_id), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the given class's
  read-model live.
  """
  @spec subscribe_class(Class.t()) :: :ok
  defdelegate subscribe_class(class), to: @implementation

  @doc """
  Reconciles a class read-model from a PubSub message broadcast on one of the
  topics of `subscribe_class/1`, returning the updated class or `:ignore` for a
  message that does not concern it.
  """
  @spec refresh_class(Class.t() | nil, term()) :: {:ok, Class.t()} | :ignore
  defdelegate refresh_class(class, message), to: @implementation

  @doc """
  Validates the data to update an existing class.
  """
  @spec validate_existing_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Changeset.t()} | {:error, :class_not_found}
  defdelegate validate_existing_class(auth, class_id, data), to: @implementation

  @doc """
  Updates the specified class with the given data.
  """
  @spec update_class(Authentication.t(), UUID.t(), Types.class_data()) ::
          {:ok, Class.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate update_class(auth, class_id, data), to: @implementation

  @doc """
  Validates the expected server properties of a class.
  """
  @spec validate_expected_server_properties_for_class(
          Authentication.t(),
          UUID.t(),
          Types.expected_server_properties()
        ) ::
          {:ok, Changeset.t()}
          | {:error, :class_not_found}
  defdelegate validate_expected_server_properties_for_class(auth, class_id, data),
    to: @implementation

  @doc """
  Updates the expected properties of a server group.
  """
  @spec update_expected_server_properties_for_class(
          Authentication.t(),
          UUID.t(),
          Types.expected_server_properties()
        ) ::
          {:ok, ExpectedServerProperties.t()}
          | {:error, Changeset.t()}
          | {:error, :class_not_found}
  defdelegate update_expected_server_properties_for_class(auth, class_id, data),
    to: @implementation

  @doc """
  Deletes the specified class. The class must not have any servers associated
  with it.
  """
  @spec delete_class(Authentication.t(), UUID.t()) ::
          :ok | {:error, :class_not_found} | {:error, :class_has_servers}
  defdelegate delete_class(auth, class_id), to: @implementation

  # Students

  @doc """
  Validates the data to create a new student.
  """
  @spec validate_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Changeset.t()} | {:error, :class_not_found}
  defdelegate validate_student(auth, class_id, data), to: @implementation

  @doc """
  Creates a new student with the specified data.
  """
  @spec create_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate create_student(auth, class_id, data), to: @implementation

  @doc """
  Imports a batch of students into a class.
  """
  @spec import_students(Authentication.t(), UUID.t(), Types.import_students_data()) ::
          {:ok, list(Student.t())} | {:error, Changeset.t()} | {:error, :class_not_found}
  defdelegate import_students(auth, class_id, data), to: @implementation

  @doc """
  Lists all students in the specified class.
  """
  @spec list_students(Authentication.t(), Class.t()) :: list(StudentView.t())
  defdelegate list_students(auth, class), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the list of students
  in the given class live.
  """
  @spec subscribe_class_students(Class.t()) :: :ok
  defdelegate subscribe_class_students(class), to: @implementation

  @doc """
  Reconciles the list of students in a class from a PubSub message broadcast on
  one of the topics of `subscribe_class_students/1`, returning the refreshed
  list or `:ignore` for a message that does not concern it.
  """
  @spec refresh_class_students(Authentication.t(), Class.t(), list(StudentView.t()), term()) ::
          {:ok, list(StudentView.t())} | :ignore
  defdelegate refresh_class_students(auth, class, students, message), to: @implementation

  @doc """
  Fetches the student who is currently authenticated.
  """
  @spec fetch_authenticated_student(Authentication.t()) ::
          {:ok, StudentView.t()} | {:error, :not_a_student}
  defdelegate fetch_authenticated_student(auth), to: @implementation

  @doc """
  Fetches a student in the given class. If the student exists but is in another
  class, it will not be found.
  """
  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, StudentView.t()} | {:error, :student_not_found}
  defdelegate fetch_student_in_class(auth, class_id, student_id), to: @implementation

  @doc """
  Validates the data to update an existing student.
  """
  @spec validate_existing_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  defdelegate validate_existing_student(auth, student_id, data), to: @implementation

  @doc """
  Updates the specified student with the given data.
  """
  @spec update_student(Authentication.t(), UUID.t(), Types.student_data()) ::
          {:ok, Student.t()} | {:error, Changeset.t()} | {:error, :student_not_found}
  defdelegate update_student(auth, student_id, data), to: @implementation

  @doc """
  Validates the data to configure a student.
  """
  @spec validate_student_config(Authentication.t(), UUID.t(), Types.student_config()) ::
          {:ok, Changeset.t()} | {:error, :student_not_found}
  defdelegate validate_student_config(auth, student_id, data), to: @implementation

  @doc """
  Configures the specified student. Whereas `update_student/3` updates the whole
  student, this only updates the configuration accessible to the student.
  """
  @spec configure_student(Authentication.t(), UUID.t(), Types.student_config()) ::
          {:ok, Student.t()}
          | {:error, Changeset.t()}
          | {:error, :student_not_found}
  defdelegate configure_student(auth, student_id, data), to: @implementation

  @doc """
  Deletes the specified student. Note that any user account associated with the
  student will lose its access.
  """
  @spec delete_student(Authentication.t(), UUID.t()) ::
          :ok | {:error, :student_not_found}
  defdelegate delete_student(auth, student_id), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the given student's
  read-model live.
  """
  @spec subscribe_student(StudentView.t()) :: :ok
  defdelegate subscribe_student(student), to: @implementation

  @doc """
  Reconciles a student read-model from a PubSub message broadcast on one of the
  topics of `subscribe_student/1`, returning the updated student or `:ignore`
  for a message that does not concern it.
  """
  @spec refresh_student(StudentView.t() | nil, term()) :: {:ok, StudentView.t()} | :ignore
  defdelegate refresh_student(student, message), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps a student detail
  read-model — the student, its nested class and its account linkage — live.
  """
  @spec subscribe_student_detail(StudentView.t()) :: :ok
  defdelegate subscribe_student_detail(student), to: @implementation

  @doc """
  Reconciles a student detail read-model (the student and its nested class) from
  a PubSub message broadcast on one of the topics of
  `subscribe_student_detail/1`, returning the updated student or `:ignore` for a
  message that does not concern it.
  """
  @spec refresh_student_detail(StudentView.t() | nil, term()) ::
          {:ok, StudentView.t()} | :ignore
  defdelegate refresh_student_detail(student, message), to: @implementation
end
