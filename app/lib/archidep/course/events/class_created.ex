defmodule ArchiDep.Course.Events.ClassCreated do
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
    alias ArchiDep.Course.Events.ClassCreated

    @spec event_stream(ClassCreated.t()) :: String.t()
    def event_stream(%ClassCreated{id: id}),
      do: "course:classes:#{id}"

    @spec event_type(ClassCreated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/class-created"
  end
end
