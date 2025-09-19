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
    :ssh_exercise_vm_ip_address,
    :servers_enabled,
    :teacher_ssh_public_keys
  ]
  defstruct [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :ssh_exercise_vm_ip_address,
    :servers_enabled,
    :teacher_ssh_public_keys
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          ssh_exercise_vm_ip_address: String.t() | nil,
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
      ssh_exercise_vm_ip_address: ssh_exercise_vm_ip_address,
      servers_enabled: servers_enabled,
      teacher_ssh_public_keys: teacher_ssh_public_keys
    } = class

    ip_address =
      case ssh_exercise_vm_ip_address do
        %Postgrex.INET{address: address} -> address |> :inet.ntoa() |> to_string()
        nil -> nil
      end

    %__MODULE__{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      ssh_exercise_vm_ip_address: ip_address,
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
