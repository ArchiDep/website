defmodule ArchiDep.Course do
  @moduledoc """
  Course context to manage classes and students and all related configuration.
  """

  @behaviour ArchiDep.Course.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Course.Types
  alias ArchiDep.CourseSite.Session

  @implementation Application.compile_env!(:archidep, __MODULE__)

  # Course progress

  @doc """
  What each session of the course recorded of the progress through it, in the
  order they were taught.

  This takes no authentication because how far the course has got is public: it
  is what the course material's own navigation is coloured by, and it is served
  at a public route so that a copy of the site built elsewhere can track it.

  The sessions are returned rather than the `ArchiDep.CourseSite.Progress` they
  add up to, because they answer two different questions and only the sessions
  answer both — see that module.
  """
  @spec course_sessions() :: [Session.t()]
  defdelegate course_sessions(), to: @implementation

  @doc """
  The global PubSub topic every change to the record of how far the course has
  got is broadcast on, before the per-test scope is applied.

  This is not a callback of the behaviour: a topic name is a constant of this
  context rather than something an implementation decides, and it is exposed
  unresolved for the one kind of subscriber that cannot resolve the scope for
  itself — a process started at application boot. See `ArchiDep.PubSub.Scope`
  and `subscribe_course_sessions/0`, which is what everything else uses.
  """
  @spec course_sessions_topic() :: String.t()
  defdelegate course_sessions_topic(), to: ArchiDep.Course.PubSub

  @doc """
  Lists every session of the course, in the order they were taught.

  This is what the admin console edits, so it answers with the records
  themselves rather than with what `course_sessions/0` derives from them.
  """
  @spec list_course_sessions(Authentication.t()) :: [CourseSession.t()]
  defdelegate list_course_sessions(auth), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the list of course
  sessions live.
  """
  @spec subscribe_course_sessions() :: :ok
  defdelegate subscribe_course_sessions(), to: @implementation

  @doc """
  Reconciles the list of course sessions from a PubSub message broadcast on one
  of the topics of `subscribe_course_sessions/0`, returning the updated list or
  `:ignore` for a message that does not concern it.
  """
  @spec refresh_course_sessions(Authentication.t(), [CourseSession.t()], term()) ::
          {:ok, [CourseSession.t()]} | :ignore
  defdelegate refresh_course_sessions(auth, course_sessions, message), to: @implementation

  @doc """
  Validates the data to record a new session of the course.
  """
  @spec validate_course_session(Authentication.t(), Types.course_session_data()) :: Changeset.t()
  defdelegate validate_course_session(auth, data), to: @implementation

  @doc """
  Records a new session of the course.
  """
  @spec create_course_session(Authentication.t(), Types.course_session_data()) ::
          {:ok, CourseSession.t()} | {:error, Changeset.t()}
  defdelegate create_course_session(auth, data), to: @implementation

  @doc """
  Validates the data to update a session of the course that was already
  recorded.
  """
  @spec validate_existing_course_session(
          Authentication.t(),
          UUID.t(),
          Types.course_session_data()
        ) ::
          {:ok, Changeset.t()} | {:error, :course_session_not_found}
  defdelegate validate_existing_course_session(auth, course_session_id, data),
    to: @implementation

  @doc """
  Updates what the specified session of the course recorded.
  """
  @spec update_course_session(Authentication.t(), UUID.t(), Types.course_session_data()) ::
          {:ok, CourseSession.t()}
          | {:error, Changeset.t()}
          | {:error, :course_session_not_found}
  defdelegate update_course_session(auth, course_session_id, data), to: @implementation

  @doc """
  Deletes the specified session of the course.
  """
  @spec delete_course_session(Authentication.t(), UUID.t()) ::
          :ok | {:error, :course_session_not_found}
  defdelegate delete_course_session(auth, course_session_id), to: @implementation

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
  @spec list_classes(Authentication.t()) :: list(ClassView.t())
  defdelegate list_classes(auth), to: @implementation

  @doc """
  Lists currently active classes.
  """
  @spec list_active_classes(Authentication.t()) :: list(ClassView.t())
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
  @spec refresh_classes(Authentication.t() | nil, list(ClassView.t()), term()) ::
          {:ok, list(ClassView.t())} | :ignore
  defdelegate refresh_classes(auth, classes, message), to: @implementation

  @doc """
  Fetches a class.
  """
  @spec fetch_class(Authentication.t() | nil, UUID.t()) ::
          {:ok, ClassView.t()} | {:error, :class_not_found}
  defdelegate fetch_class(auth, class_id), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the given class's
  read-model live.
  """
  @spec subscribe_class(ClassView.t()) :: :ok
  defdelegate subscribe_class(class), to: @implementation

  @doc """
  Reconciles a class read-model from a PubSub message broadcast on one of the
  topics of `subscribe_class/1`, returning the updated class or `:ignore` for a
  message that does not concern it.
  """
  @spec refresh_class(ClassView.t() | nil, term()) :: {:ok, ClassView.t()} | :ignore
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
  @spec list_students(Authentication.t(), ClassView.t()) :: list(StudentView.t())
  defdelegate list_students(auth, class), to: @implementation

  @doc """
  Subscribes the calling process to every topic that keeps the list of students
  in the given class live.
  """
  @spec subscribe_class_students(ClassView.t()) :: :ok
  defdelegate subscribe_class_students(class), to: @implementation

  @doc """
  Reconciles the list of students in a class from a PubSub message broadcast on
  one of the topics of `subscribe_class_students/1`, returning the refreshed
  list or `:ignore` for a message that does not concern it.
  """
  @spec refresh_class_students(Authentication.t(), ClassView.t(), list(StudentView.t()), term()) ::
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
