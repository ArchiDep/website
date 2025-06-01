defmodule ArchiDep.Students.Events.StudentDeleted do
  use ArchiDep, :event

  alias ArchiDep.Students.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name
  ]
  defstruct [
    :id,
    :name
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name
    } = student

    %__MODULE__{
      id: id,
      name: name
    }
  end

  defimpl Event do
    alias ArchiDep.Students.Events.StudentDeleted

    def event_stream(%StudentDeleted{id: id}),
      do: "students:#{id}"

    def event_type(_event), do: :"archidep/students/student-deleted"
  end
end
