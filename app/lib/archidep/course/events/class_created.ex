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
    :ssh_exercise_vm_ip_address,
    :servers_enabled
  ]
  defstruct [
    :id,
    :name,
    :start_date,
    :end_date,
    :active,
    :ssh_exercise_vm_ip_address,
    :servers_enabled
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          ssh_exercise_vm_ip_address: String.t() | nil,
          servers_enabled: boolean()
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
      servers_enabled: servers_enabled
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
      servers_enabled: servers_enabled
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
