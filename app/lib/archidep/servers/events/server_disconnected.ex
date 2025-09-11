defmodule ArchiDep.Servers.Events.ServerDisconnected do
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
    :uptime,
    :reason,
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
    :uptime,
    :reason,
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
          uptime: non_neg_integer(),
          reason: String.t() | nil,
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

  @spec new(Server.t(), String.t(), non_neg_integer(), String.t() | nil) :: t()
  def new(server, ssh_username, uptime, reason) do
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

    serialized_reason =
      case reason do
        nil -> nil
        text when is_binary(text) -> text
        term -> inspect(term)
      end

    %__MODULE__{
      id: id,
      name: name,
      ip_address: ip_address.address |> :inet.ntoa() |> to_string(),
      username: username,
      ssh_username: ssh_username,
      ssh_port: ssh_port,
      uptime: uptime,
      reason: serialized_reason,
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
    alias ArchiDep.Servers.Events.ServerDisconnected

    @spec event_stream(ServerDisconnected.t()) :: String.t()
    def event_stream(%ServerDisconnected{id: id}),
      do: "servers:servers:#{id}"

    @spec event_type(ServerDisconnected.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/server-disconnected"
  end
end
