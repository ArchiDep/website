defmodule ArchiDep.Servers.Events.ServerOpenPortsChecked do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username,
    :app_username,
    :ssh_port,
    :ports,
    :group,
    :owner
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username,
    :app_username,
    :ssh_port,
    :ports,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          app_username: String.t(),
          ssh_port: 1..65_535 | nil,
          ports: list(1..65_535),
          group: %{
            id: UUID.t(),
            name: String.t()
          },
          owner: %{
            id: UUID.t(),
            username: String.t() | nil,
            name: String.t() | nil,
            root: boolean()
          }
        }

  @spec new(Server.t(), list(1..65_535)) :: t()
  def new(server, ports) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      app_username: app_username,
      ssh_port: ssh_port,
      group: group,
      owner: owner
    } = server

    %ServerGroup{
      id: group_id,
      name: group_name
    } = group

    %ServerOwner{
      id: owner_id,
      username: owner_username,
      group_member: group_member,
      root: owner_root
    } = owner

    owner_name =
      case group_member do
        %ServerGroupMember{name: name} -> name
        nil -> nil
      end

    %__MODULE__{
      id: id,
      name: name,
      ip_address: ip_address.address |> :inet.ntoa() |> to_string(),
      username: username,
      app_username: app_username,
      ssh_port: ssh_port,
      ports: ports,
      group: %{
        id: group_id,
        name: group_name
      },
      owner: %{
        id: owner_id,
        username: owner_username,
        name: owner_name,
        root: owner_root
      }
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.ServerOpenPortsChecked

    @spec event_stream(ServerOpenPortsChecked.t()) :: String.t()
    def event_stream(%ServerOpenPortsChecked{id: id}),
      do: "servers:servers:#{id}"

    @spec event_type(ServerOpenPortsChecked.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/server-open-ports-checked"
  end
end
