defmodule ArchiDep.Servers.Events.ServerUpdated do
  use ArchiDep, :event

  alias ArchiDep.Servers.Schemas.Server
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_port,
    :user_account_id,
    :expected_cpus,
    :expected_cores,
    :expected_vcpus,
    :expected_memory,
    :expected_swap,
    :expected_system,
    :expected_architecture,
    :expected_os_family,
    :expected_distribution,
    :expected_distribution_release,
    :expected_distribution_version
  ]
  defstruct [
    :id,
    :name,
    :ip_address,
    :username,
    :ssh_port,
    :user_account_id,
    :expected_cpus,
    :expected_cores,
    :expected_vcpus,
    :expected_memory,
    :expected_swap,
    :expected_system,
    :expected_architecture,
    :expected_os_family,
    :expected_distribution,
    :expected_distribution_release,
    :expected_distribution_version
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: 1..65_535 | nil,
          user_account_id: UUID.t(),
          expected_cpus: non_neg_integer() | nil,
          expected_cores: non_neg_integer() | nil,
          expected_vcpus: non_neg_integer() | nil,
          expected_memory: non_neg_integer() | nil,
          expected_swap: non_neg_integer() | nil,
          expected_system: String.t() | nil,
          expected_architecture: String.t() | nil,
          expected_os_family: String.t() | nil,
          expected_distribution: String.t() | nil,
          expected_distribution_release: String.t() | nil,
          expected_distribution_version: String.t() | nil
        }

  @spec new(Server.t()) :: t()
  def new(server) do
    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      ssh_port: ssh_port,
      user_account_id: user_account_id,
      expected_cpus: expected_cpus,
      expected_cores: expected_cores,
      expected_vcpus: expected_vcpus,
      expected_memory: expected_memory,
      expected_swap: expected_swap,
      expected_system: expected_system,
      expected_architecture: expected_architecture,
      expected_os_family: expected_os_family,
      expected_distribution: expected_distribution,
      expected_distribution_release: expected_distribution_release,
      expected_distribution_version: expected_distribution_version
    } = server

    %__MODULE__{
      id: id,
      name: name,
      ip_address: to_string(:inet.ntoa(ip_address.address)),
      username: username,
      ssh_port: ssh_port,
      user_account_id: user_account_id,
      expected_cpus: expected_cpus,
      expected_cores: expected_cores,
      expected_vcpus: expected_vcpus,
      expected_memory: expected_memory,
      expected_swap: expected_swap,
      expected_system: expected_system,
      expected_architecture: expected_architecture,
      expected_os_family: expected_os_family,
      expected_distribution: expected_distribution,
      expected_distribution_release: expected_distribution_release,
      expected_distribution_version: expected_distribution_version
    }
  end

  defimpl Event do
    alias ArchiDep.Servers.Events.ServerUpdated

    def event_stream(%ServerUpdated{id: id}),
      do: "servers:#{id}"

    def event_type(_event), do: :"archidep/servers/server-updated"
  end
end
