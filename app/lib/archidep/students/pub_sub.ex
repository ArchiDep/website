defmodule ArchiDep.Students.PubSub do
  use ArchiDep, :pub_sub

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @pubsub ArchiDep.PubSub

  @spec publish_class_created(Class.t()) :: :ok
  def publish_class_created(class),
    do: PubSub.broadcast(@pubsub, "classes", {:class_created, class})

  @spec subscribe_classes() :: :ok
  def subscribe_classes() do
    :ok = PubSub.subscribe(@pubsub, "classes")
  end

  @spec publish_class(Class.t()) :: :ok
  def publish_class(class),
    do: PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_updated, class})

  @spec publish_class_deleted(Class.t()) :: :ok
  def publish_class_deleted(class),
    do: PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_deleted, class})

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

  @spec publish_student(Student.t()) :: :ok
  def publish_student(student),
    do: PubSub.broadcast(@pubsub, "students:#{student.id}", {:student_updated, student})

  @spec publish_student_deleted(Student.t()) :: :ok
  def publish_student_deleted(student),
    do: PubSub.broadcast(@pubsub, "students:#{student.id}", {:student_deleted, student})

  @spec subscribe_student(UUID.t()) :: :ok
  def subscribe_student(student_id) do
    :ok = PubSub.subscribe(@pubsub, "students:#{student_id}")
  end

  @spec unsubscribe_student(UUID.t()) :: :ok
  def unsubscribe_student(student_id) do
    :ok = PubSub.unsubscribe(@pubsub, "students:#{student_id}")
  end
end
