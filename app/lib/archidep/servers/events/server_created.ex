defmodule ArchiDep.Servers.Events.ServerCreated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_port,
    :group_id,
    :expected_properties
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_port,
    :group_id,
    :expected_properties
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: 1..65_535 | nil,
          group_id: UUID.t(),
          expected_properties: %{
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
          }
        }

  @spec new(Server.t()) :: t()
  def new(server) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      ssh_port: ssh_port,
      group_id: group_id,
      expected_properties: %ServerProperties{
        hostname: expected_hostname,
        machine_id: expected_machine_id,
        cpus: expected_cpus,
        cores: expected_cores,
        vcpus: expected_vcpus,
        memory: expected_memory,
        swap: expected_swap,
        system: expected_system,
        architecture: expected_architecture,
        os_family: expected_os_family,
        distribution: expected_distribution,
        distribution_release: expected_distribution_release,
        distribution_version: expected_distribution_version
      }
    } = server

    %__MODULE__{
      id: id,
      name: name,
      ip_address: to_string(:inet.ntoa(ip_address.address)),
      username: username,
      ssh_port: ssh_port,
      group_id: group_id,
      expected_properties: %{
        hostname: expected_hostname,
        machine_id: expected_machine_id,
        cpus: expected_cpus,
        cores: expected_cores,
        vcpus: expected_vcpus,
        memory: expected_memory,
        swap: expected_swap,
        system: expected_system,
        architecture: expected_architecture,
        os_family: expected_os_family,
        distribution: expected_distribution,
        distribution_release: expected_distribution_release,
        distribution_version: expected_distribution_version
      }
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.ServerCreated

    @spec event_stream(ServerCreated.t()) :: String.t()
    def event_stream(%ServerCreated{id: id}),
      do: "servers:#{id}"

    @spec event_type(ServerCreated.t()) :: atom()
    def event_type(_event), do: :"archidep/servers/server-created"
  end
end
