defmodule ArchiDep.Students.PubSub do
  use ArchiDep, :pub_sub

  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student

  @pubsub ArchiDep.PubSub

  @spec publish_class(Class.t()) :: :ok
  def publish_class(class),
    do: PubSub.broadcast(@pubsub, "classes:#{class.id}", {:class_updated, class})

  @spec subscribe_class(UUID.t()) :: :ok | {:error, :class_not_found}
  def subscribe_class(class_id) do
    # TODO: use simpler query to check if class exists
    with {:ok, _class} <- Class.fetch_class(class_id) do
      :ok = PubSub.subscribe(@pubsub, "classes:#{class_id}")
    end
  end

  @spec publish_student(Student.t()) :: :ok
  def publish_student(student),
    do: PubSub.broadcast(@pubsub, "students:#{student.id}", {:student_updated, student})

  @spec subscribe_student(UUID.t()) :: :ok | {:error, :student_not_found}
  def subscribe_student(student_id) do
    # TODO: use simpler query to check if student exists
    with {:ok, _student} <- Student.fetch_student(student_id) do
      :ok = PubSub.subscribe(@pubsub, "students:#{student_id}")
    end
  end
end
