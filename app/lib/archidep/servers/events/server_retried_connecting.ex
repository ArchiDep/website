defmodule ArchiDep.Servers.Events.ServerRetriedConnecting do
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
    :ssh_username,
    :ssh_port,
    :group,
    :owner
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_username,
    :ssh_port,
    :group,
    :owner
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_username: String.t(),
          ssh_port: 1..65_535 | nil,
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

  @spec new(Server.t(), String.t()) :: t()
  def new(server, ssh_username) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
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
      ssh_username: ssh_username,
      ssh_port: ssh_port,
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
    alias ArchiDep.Servers.Events.ServerRetriedConnecting

    @spec event_stream(ServerRetriedConnecting.t()) :: String.t()
    def event_stream(%ServerRetriedConnecting{id: id}),
      do: "servers:servers:#{id}"

    @spec event_type(ServerRetriedConnecting.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/server-retried-connecting"
  end
end
