defmodule ArchiDep.Course.UseCases.ReadStudents do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Accounts
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Policy
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.EventReference

  @spec list_students(Authentication.t(), Class.t()) :: list(Student.t())
  def list_students(auth, class) do
    authorize!(auth, Policy, :course, :list_students, class)
    Student.list_students_in_class(class.id)
  end

  # Subscribing to the topics of a class the caller already holds grants no new
  # access, so this read-model plumbing takes no authentication and skips the
  # authorization the command use cases perform. The list of students in a class
  # is kept live by the Course students topic and by the Accounts
  # preregistered-users topic (a linked account changing affects a student's
  # displayed identity); the class id and its user group id are the same.
  @spec subscribe_class_students(Class.t()) :: :ok
  def subscribe_class_students(%Class{id: id}) do
    :ok = PubSub.subscribe_class_students(id)
    :ok = Accounts.PubSub.subscribe_user_group_preregistered_users(id)
  end

  @spec refresh_class_students(Authentication.t(), Class.t(), list(Student.t()), term()) ::
          {:ok, list(Student.t())} | :ignore
  def refresh_class_students(auth, %Class{id: id} = class, students, message)
      when is_list(students) do
    if concerns_class_students?(message, id) do
      {:ok, list_students(auth, class)}
    else
      :ignore
    end
  end

  defp concerns_class_students?({student_event, %Student{class_id: id}}, id)
       when student_event in [:student_created, :student_deleted],
       do: true

  defp concerns_class_students?({:student_updated, %{class: %{id: id}}, %EventReference{}}, id),
    do: true

  defp concerns_class_students?({:students_imported, %Class{id: id}, students}, id)
       when is_list(students),
       do: true

  defp concerns_class_students?({:preregistered_user_updated, _event, %EventReference{}}, _id),
    do: true

  defp concerns_class_students?(_message, _id), do: false

  @spec fetch_authenticated_student(Authentication.t()) ::
          {:ok, Student.t()} | {:error, :not_a_student}
  def fetch_authenticated_student(auth) do
    with {:ok, student} <-
           auth |> Authentication.principal_id() |> Student.fetch_student_for_user_account_id(),
         :ok <- authorize(auth, Policy, :course, :fetch_authenticated_student, student) do
      {:ok, student}
    else
      {:error, :student_not_found} ->
        {:error, :not_a_student}
    end
  end

  @spec fetch_student_in_class(Authentication.t(), UUID.t(), UUID.t()) ::
          {:ok, Student.t()} | {:error, :student_not_found}
  def fetch_student_in_class(auth, class_id, id) do
    with :ok <- validate_uuid(class_id, :student_not_found),
         :ok <- validate_uuid(id, :student_not_found),
         {:ok, student} <- Student.fetch_student_in_class(class_id, id),
         :ok <- authorize(auth, Policy, :course, :fetch_student_in_class, student) do
      {:ok, student}
    else
      {:error, :student_not_found} ->
        {:error, :student_not_found}

      {:error, {:access_denied, :course, :fetch_student_in_class}} ->
        {:error, :student_not_found}
    end
  end

  # Subscribing to the topic of a student the caller already holds grants no new
  # access, so this read-model plumbing takes no authentication and skips the
  # authorization the command use cases perform.
  @spec subscribe_student(Student.t()) :: :ok
  def subscribe_student(%Student{id: id}), do: PubSub.subscribe_student(id)

  @spec refresh_student(Student.t() | nil, term()) :: {:ok, Student.t()} | :ignore
  def refresh_student(
        %Student{id: id} = student,
        {:student_updated, %{id: id} = event, %EventReference{} = reference}
      ),
      do: {:ok, Student.refresh!(student, event, reference)}

  def refresh_student(_student, _message), do: :ignore

  # Subscribing to the topics of a student the caller already holds grants no
  # new access, so this read-model plumbing takes no authentication. The admin
  # student detail page keeps the student, its nested class and its account
  # linkage live, so it rides the student topic, the class topic and the
  # Accounts preregistration topic (both keyed by ids fixed for the page's
  # lifetime).
  @spec subscribe_student_detail(Student.t()) :: :ok
  def subscribe_student_detail(%Student{id: id, class_id: class_id}) do
    :ok = PubSub.subscribe_student(id)
    :ok = PubSub.subscribe_class(class_id)
    :ok = Accounts.PubSub.subscribe_preregistered_user(id)
  end

  @spec refresh_student_detail(Student.t() | nil, term()) :: {:ok, Student.t()} | :ignore
  def refresh_student_detail(
        %Student{id: id} = student,
        {:student_updated, %{id: id} = event, %EventReference{} = reference}
      ),
      do: {:ok, Student.refresh!(student, event, reference)}

  def refresh_student_detail(
        %Student{class_id: class_id, class: %Class{} = class} = student,
        {:class_updated, event, %EventReference{} = reference}
      ) do
    if class_updated_id(event) == class_id do
      {:ok, %Student{student | class: Class.refresh!(class, event, reference)}}
    else
      :ignore
    end
  end

  def refresh_student_detail(_student, _message), do: :ignore

  defp class_updated_id(%ClassUpdated{id: id}), do: id
  defp class_updated_id(%ClassExpectedServerPropertiesUpdated{class: %{id: id}}), do: id
end
