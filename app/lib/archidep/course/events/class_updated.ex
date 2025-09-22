defmodule ArchiDep.Course.Events.ClassUpdated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :servers_enabled,
    :teacher_ssh_public_keys
  ]
  defstruct [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :servers_enabled,
    :teacher_ssh_public_keys
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          servers_enabled: boolean(),
          teacher_ssh_public_keys: list(String.t())
        }

  @spec new(Class.t()) :: t()
  def new(class) do
    %Class{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      teacher_ssh_public_keys: teacher_ssh_public_keys
    } = class

    %__MODULE__{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      teacher_ssh_public_keys: teacher_ssh_public_keys
    }
  end

  defimpl Event do
    alias ArchiDep.Course.Events.ClassUpdated

    @spec event_stream(ClassUpdated.t()) :: String.t()
    def event_stream(%ClassUpdated{id: id}),
      do: "course:classes:#{id}"

    @spec event_type(ClassUpdated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/class-updated"
  end
end
