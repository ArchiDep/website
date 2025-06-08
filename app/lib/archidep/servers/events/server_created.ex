defmodule ArchiDep.Servers.Events.ServerCreated do
  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t()
        }

  @spec new(Server.t()) :: t()
  def new(server) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username
    } = server

    %__MODULE__{
      id: id,
      name: name,
      ip_address: to_string(:inet.ntoa(ip_address.address)),
      username: username
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.ServerCreated

    def event_stream(%ServerCreated{id: id}),
      do: "servers:#{id}"

    def event_type(_event), do: :"archidep/servers/server-created"
  end
end
