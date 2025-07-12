defmodule ArchiDep.Course.Events.StudentUpdated do
  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Student
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :email
  ]
  defstruct [
    :id,
    :name,
    :email
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          email: String.t()
        }

  @spec new(Student.t()) :: t()
  def new(student) do
    %Student{
      id: id,
      name: name,
      email: email
    } = student

    %__MODULE__{
      id: id,
      name: name,
      email: email
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.StudentUpdated

    def event_stream(%StudentUpdated{id: id}),
      do: "students:#{id}"

    def event_type(_event), do: :"archidep/students/student-updated"
  end
end
