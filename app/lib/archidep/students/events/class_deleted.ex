defmodule ArchiDep.Students.Events.ClassDeleted do
  alias ArchiDep.Students.Schemas.Class
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

  @spec new(Class.t()) :: t()
  def new(class) do
    %Class{
      id: id,
      name: name
    } = class

    %__MODULE__{
      id: id,
      name: name
    }
  end
end
