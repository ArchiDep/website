defmodule ArchiDep.Servers.Events.ServerFactsGathered do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_username,
    :ssh_port,
    :last_known_properties,
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
    :last_known_properties,
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
          last_known_properties: %{
            id: UUID.t(),
            hostname: String.t() | nil,
            machine_id: String.t() | nil,
            cpus: non_neg_integer() | nil,
            cores: non_neg_integer() | nil,
            vcpus: non_neg_integer() | nil,
            memory: non_neg_integer() | nil,
            swap: non_neg_integer() | nil,
            system: String.t() | nil,
            architecture: String.t() | nil,
            os_family: String.t() | nil,
            distribution: String.t() | nil,
            distribution_release: String.t() | nil,
            distribution_version: String.t() | nil
          },
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

  @spec event_version() :: pos_integer()
  def event_version, do: 2

  @spec new(Server.t()) :: t()
  def new(server) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      app_username: app_username,
      ssh_port: ssh_port,
      group: group,
      owner: owner,
      last_known_properties: %ServerProperties{
        id: properties_id,
        hostname: hostname,
        machine_id: machine_id,
        cpus: cpus,
        cores: cores,
        vcpus: vcpus,
        memory: memory,
        swap: swap,
        system: system,
        architecture: architecture,
        os_family: os_family,
        distribution: distribution,
        distribution_release: distribution_release,
        distribution_version: distribution_version
      }
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
      ssh_username: app_username,
      ssh_port: ssh_port,
      last_known_properties: %{
        id: properties_id,
        hostname: hostname,
        machine_id: machine_id,
        cpus: cpus,
        cores: cores,
        vcpus: vcpus,
        memory: memory,
        swap: swap,
        system: system,
        architecture: architecture,
        os_family: os_family,
        distribution: distribution,
        distribution_release: distribution_release,
        distribution_version: distribution_version
      },
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
    alias ArchiDep.Servers.Events.ServerFactsGathered

    @spec event_stream(ServerFactsGathered.t()) :: String.t()
    def event_stream(%ServerFactsGathered{id: id}),
      do: "servers:servers:#{id}"

    @spec event_type(ServerFactsGathered.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/server-facts-gathered"
  end
end
