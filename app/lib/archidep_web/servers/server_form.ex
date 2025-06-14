defmodule ArchiDepWeb.Servers.ServerForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset
  alias Ecto.UUID

  @type t :: %__MODULE__{
          name: String.t() | nil,
          ip_address: String.t(),
          username: String.t(),
          ssh_port: integer() | nil,
          class_id: UUID.t() | nil,
          app_username: String.t(),
          expected_cpus: pos_integer() | nil,
          expected_cores: pos_integer() | nil,
          expected_vcpus: pos_integer() | nil,
          expected_memory: pos_integer() | nil,
          expected_swap: pos_integer() | nil,
          expected_system: String.t() | nil,
          expected_architecture: String.t() | nil,
          expected_os_family: String.t() | nil,
          expected_distribution: String.t() | nil,
          expected_distribution_release: String.t() | nil,
          expected_distribution_version: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:ip_address, :string)
    field(:username, :string)
    field(:ssh_port, :integer)
    field(:class_id, :binary_id)
    field(:app_username, :string)
    field(:expected_cpus, :integer)
    field(:expected_cores, :integer)
    field(:expected_vcpus, :integer)
    field(:expected_memory, :integer)
    field(:expected_swap, :integer)
    field(:expected_system, :string)
    field(:expected_architecture, :string)
    field(:expected_os_family, :string)
    field(:expected_distribution, :string)
    field(:expected_distribution_release, :string)
    field(:expected_distribution_version, :string)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :class_id,
      :app_username,
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
    ])
    |> validate_required([:ip_address, :username, :class_id])
  end

  @spec update_changeset(Server.t(), map) :: Changeset.t(t())
  def update_changeset(server, params \\ %{}) when is_struct(server, Server) and is_map(params) do
    %__MODULE__{
      name: server.name,
      ip_address: server.ip_address,
      username: server.username,
      ssh_port: server.ssh_port,
      class_id: server.class_id,
      app_username: server.app_username,
      expected_cpus: server.expected_cpus,
      expected_cores: server.expected_cores,
      expected_vcpus: server.expected_vcpus,
      expected_memory: server.expected_memory,
      expected_swap: server.expected_swap,
      expected_system: server.expected_system,
      expected_architecture: server.expected_architecture,
      expected_os_family: server.expected_os_family,
      expected_distribution: server.expected_distribution,
      expected_distribution_release: server.expected_distribution_release,
      expected_distribution_version: server.expected_distribution_version
    }
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :app_username,
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
    ])
    |> validate_required([:ip_address, :username])
  end

  @spec to_create_server_data(t()) :: Types.create_server_data()
  def to_create_server_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      ip_address: form.ip_address,
      username: form.username,
      ssh_port: form.ssh_port,
      class_id: form.class_id,
      app_username: form.app_username,
      expected_cpus: form.expected_cpus,
      expected_cores: form.expected_cores,
      expected_vcpus: form.expected_vcpus,
      expected_memory: form.expected_memory,
      expected_swap: form.expected_swap,
      expected_system: form.expected_system,
      expected_architecture: form.expected_architecture,
      expected_os_family: form.expected_os_family,
      expected_distribution: form.expected_distribution,
      expected_distribution_release: form.expected_distribution_release,
      expected_distribution_version: form.expected_distribution_version
    }
  end

  @spec to_update_server_data(t()) :: Types.update_server_data()
  def to_update_server_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      ip_address: form.ip_address,
      username: form.username,
      ssh_port: form.ssh_port,
      app_username: form.app_username,
      expected_cpus: form.expected_cpus,
      expected_cores: form.expected_cores,
      expected_vcpus: form.expected_vcpus,
      expected_memory: form.expected_memory,
      expected_swap: form.expected_swap,
      expected_system: form.expected_system,
      expected_architecture: form.expected_architecture,
      expected_os_family: form.expected_os_family,
      expected_distribution: form.expected_distribution,
      expected_distribution_release: form.expected_distribution_release,
      expected_distribution_version: form.expected_distribution_version
    }
  end
end
