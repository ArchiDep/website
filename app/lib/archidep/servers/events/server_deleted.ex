defmodule ArchiDep.Servers.Events.ServerDeleted do
  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :ssh_port
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :ssh_port
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          ip_address: String.t(),
          ssh_port: 1..65_535
        }

  @spec new(Server.t()) :: t()
  def new(server) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      ssh_port: ssh_port
    } = server

    %__MODULE__{
      id: id,
      name: name,
      ip_address: to_string(:inet.ntoa(ip_address.address)),
      ssh_port: ssh_port || 22
    }
  end

  defimpl Event do
    def event_stream(%ArchiDep.Servers.Events.ServerDeleted{id: id}),
      do: "servers:#{id}"

    def event_type(_event), do: :"archidep/servers/server-deleted"
  end
end
