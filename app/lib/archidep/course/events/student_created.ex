defmodule ArchiDep.Course.Events.StudentCreated do
  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email,
    :class_id
  ]
  defstruct [
    :id,
    :name,
    :email,
    :class_id
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t(),
          class_id: UUID.t()
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name,
      email: email,
      class_id: class_id
    } = student

    %__MODULE__{
      id: id,
      name: name,
      email: email,
      class_id: class_id
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentCreated

    def event_stream(%StudentCreated{id: id}),
      do: "students:#{id}"

    def event_type(_event), do: :"archidep/students/student-created"
  end
end
