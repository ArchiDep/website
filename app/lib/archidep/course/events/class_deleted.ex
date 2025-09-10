defmodule ArchiDep.Course.Events.ClassDeleted do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
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

  defimpl Event do
    alias ArchiDep.Course.Events.ClassDeleted

    @spec event_stream(ClassDeleted.t()) :: String.t()
    def event_stream(%ClassDeleted{id: id}),
      do: "course:classes:#{id}"

    @spec event_type(ClassDeleted.t()) :: atom()
    def event_type(_event), do: :"archidep/course/class-deleted"
  end
end
