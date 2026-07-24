defmodule ArchiDep.Course.PubSub do
  @moduledoc """
  Publication and subscription of events related to course classes and students.
  """

  use ArchiDep, :pub_sub

  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentCreated
  alias ArchiDep.Course.Events.StudentDeleted
  alias ArchiDep.Course.Events.StudentsImportedInClass
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.EventReference

  @pubsub ArchiDep.PubSub

  @spec publish_class_created(ClassCreated.t(), EventReference.t()) :: :ok
  def publish_class_created(event, reference),
    do:
      PubSub.broadcast(
        @pubsub,
        Scope.global_topic("classes"),
        {:class_created, event, reference}
      )

  @spec subscribe_classes() :: :ok
  def subscribe_classes do
    :ok = PubSub.subscribe(@pubsub, Scope.global_topic("classes"))
  end

  @spec publish_class_updated(
          Class.t(),
          ClassUpdated.t() | ClassExpectedServerPropertiesUpdated.t(),
          EventReference.t()
        ) :: :ok
  def publish_class_updated(class, event, reference) do
    message = {:class_updated, event, reference}
    :ok = PubSub.broadcast(@pubsub, "classes:#{class.id}", message)
    :ok = PubSub.broadcast(@pubsub, Scope.global_topic("classes"), message)
  end

  @spec publish_class_deleted(ClassDeleted.t(), EventReference.t()) :: :ok
  def publish_class_deleted(event, reference) do
    message = {:class_deleted, event, reference}
    :ok = PubSub.broadcast(@pubsub, "classes:#{event.id}", message)
    :ok = PubSub.broadcast(@pubsub, Scope.global_topic("classes"), message)
  end

  @spec subscribe_class(UUID.t()) :: :ok
  def subscribe_class(class_id) do
    :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}")
  end

  @spec unsubscribe_class(UUID.t()) :: :ok
  def unsubscribe_class(class_id) do
    :ok = PubSub.unsubscribe(@pubsub, "classes:#{class_id}")
  end

  @spec publish_student_created(StudentCreated.t(), EventReference.t()) :: :ok
  def publish_student_created(%StudentCreated{class: %{id: class_id}} = event, reference),
    do:
      PubSub.broadcast(
        @pubsub,
        "classes:#{class_id}:students",
        {:student_created, event, reference}
      )

  @spec publish_students_imported(StudentsImportedInClass.t(), EventReference.t()) :: :ok
  def publish_students_imported(%StudentsImportedInClass{class_id: class_id} = event, reference),
    do:
      PubSub.broadcast(
        @pubsub,
        "classes:#{class_id}:students",
        {:students_imported, event, reference}
      )

  @spec subscribe_class_students(UUID.t()) :: :ok
  def subscribe_class_students(class_id) do
    :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}:students")
  end

  @spec publish_student_updated(
          Student.t(),
          StudentUpdated.t() | StudentConfigured.t(),
          EventReference.t()
        ) :: :ok
  def publish_student_updated(student, event, reference) do
    message = {:student_updated, event, reference}
    :ok = PubSub.broadcast(@pubsub, "students:#{student.id}", message)
    :ok = PubSub.broadcast(@pubsub, "classes:#{student.class_id}:students", message)
  end

  @spec publish_student_deleted(StudentDeleted.t(), EventReference.t()) :: :ok
  def publish_student_deleted(%StudentDeleted{class: %{id: class_id}} = event, reference) do
    message = {:student_deleted, event, reference}
    :ok = PubSub.broadcast(@pubsub, "students:#{event.id}", message)
    :ok = PubSub.broadcast(@pubsub, "classes:#{class_id}:students", message)
  end

  @spec subscribe_student(UUID.t()) :: :ok
  def subscribe_student(student_id) do
    :ok = PubSub.subscribe(@pubsub, "students:#{student_id}")
  end
end
