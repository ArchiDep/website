defmodule ArchiDep.Students.Events.StudentUpdated do
  alias ArchiDep.Students.Schemas.Student
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
end
