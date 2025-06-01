defmodule ArchiDep.Students.Events.StudentDeleted do
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
end
