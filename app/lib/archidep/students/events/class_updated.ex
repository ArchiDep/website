defmodule ArchiDep.Students.Events.ClassUpdated do
  use ArchiDep, :event

  alias ArchiDep.Students.Schemas.Class
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :start_date,
    :end_date,
    :active
  ]
  defstruct [
    :id,
    :name,
    :start_date,
    :end_date,
    :active
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean()
        }

  @spec new(Class.t()) :: t()
  def new(class) do
    %Class{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active
    } = class

    %__MODULE__{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active
    }
  end

  defimpl Event do
    alias ArchiDep.Students.Events.ClassUpdated

    def event_stream(%ClassUpdated{id: id}),
      do: "classes:#{id}"

    def event_type(_event), do: :"archidep/students/class-updated"
  end
end
