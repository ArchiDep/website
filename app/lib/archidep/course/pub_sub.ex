defmodule ArchiDep.Course.PubSub do
  @moduledoc """
  Publication and subscription of events related to course classes and students.
  """

  use ArchiDep, :pub_sub

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Events.Store.EventReference

  @pubsub ArchiDep.PubSub

  @spec publish_class_created(Class.t()) :: :ok
  def publish_class_created(class),
    do: PubSub.broadcast(@pubsub, "classes", {:class_created, class})

  @spec subscribe_classes() :: :ok
  def subscribe_classes do
    :ok = PubSub.subscribe(@pubsub, "classes")
  end

  @spec publish_class_updated(Class.t(), EventReference.t()) :: :ok
  def publish_class_updated(class, event) do
    :ok = PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_updated, class, event})
    :ok = PubSub.broadcast(@pubsub, "classes", {:class_updated, class, event})
  end

  @spec publish_class_deleted(Class.t()) :: :ok
  def publish_class_deleted(class) do
    :ok = PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_deleted, class})
    :ok = PubSub.broadcast(@pubsub, "classes", {:class_deleted, class})
  end

  @spec subscribe_class(UUID.t()) :: :ok
  def subscribe_class(class_id) do
    :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}")
  end

  @spec unsubscribe_class(UUID.t()) :: :ok
  def unsubscribe_class(class_id) do
    :ok = PubSub.unsubscribe(@pubsub, "classes:#{class_id}")
  end

  @spec publish_student_created(Student.t()) :: :ok
  def publish_student_created(%Student{class_id: class_id} = student),
    do: PubSub.broadcast(@pubsub, "classes:#{class_id}:students", {:student_created, student})

  @spec publish_students_imported(Class.t(), list(Student.t())) :: :ok
  def publish_students_imported(%Class{id: class_id} = class, students),
    do:
      PubSub.broadcast(
        @pubsub,
        "classes:#{class_id}:students",
        {:students_imported, class, students}
      )

  @spec subscribe_class_students(UUID.t()) :: :ok
  def subscribe_class_students(class_id) do
    :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}:students")
  end

  @spec publish_student_updated(Student.t()) :: :ok
  def publish_student_updated(student) do
    :ok = PubSub.broadcast(@pubsub, "students:#{student.id}", {:student_updated, student})

    :ok =
      PubSub.broadcast(
        @pubsub,
        "classes:#{student.class_id}:students",
        {:student_updated, student}
      )
  end

  @spec publish_student_deleted(Student.t()) :: :ok
  def publish_student_deleted(student) do
    :ok = PubSub.broadcast(@pubsub, "students:#{student.id}", {:student_deleted, student})

    :ok =
      PubSub.broadcast(
        @pubsub,
        "classes:#{student.class_id}:students",
        {:student_deleted, student}
      )
  end

  @spec subscribe_student(UUID.t()) :: :ok
  def subscribe_student(student_id) do
    :ok = PubSub.subscribe(@pubsub, "students:#{student_id}")
  end
end
