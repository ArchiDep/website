defmodule ArchiDep.Course.Events.StudentCreated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email,
    :class_id,
    :class_name
  ]
  defstruct [
    :id,
    :name,
    :email,
    :class_id,
    :class_name
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          class_id: UUID.t(),
          class_name: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name,
      email: email,
      class: class
    } = student

    %Class{
      id: class_id,
      name: class_name
    } = class

    %__MODULE__{
      id: id,
      name: name,
      email: email,
      class_id: class_id,
      class_name: class_name
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentCreated

    @spec event_stream(StudentCreated.t()) :: String.t()
    def event_stream(%StudentCreated{id: id}),
      do: "course:students:#{id}"

    @spec event_type(StudentCreated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/student-created"
  end
end
