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
          active: boolean(),
          class_id: UUID.t() | nil,
          app_username: String.t(),
          expected_properties: %{
            id: UUID.t() | nil,
            cpus: pos_integer() | nil,
            cores: pos_integer() | nil,
            vcpus: pos_integer() | nil,
            memory: pos_integer() | nil,
            swap: pos_integer() | nil,
            system: String.t() | nil,
            architecture: String.t() | nil,
            os_family: String.t() | nil,
            distribution: String.t() | nil,
            distribution_release: String.t() | nil,
            distribution_version: String.t() | nil
          }
        }

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:ip_address, :string)
    field(:username, :string)
    field(:ssh_port, :integer)
    field(:active, :boolean, default: true)
    field(:class_id, :binary_id)
    field(:app_username, :string)

    embeds_one :expected_properties, ExpectedProperties do
      field(:cpus, :integer)
      field(:cores, :integer)
      field(:vcpus, :integer)
      field(:memory, :integer)
      field(:swap, :integer)
      field(:system, :string)
      field(:architecture, :string)
      field(:os_family, :string)
      field(:distribution, :string)
      field(:distribution_release, :string)
      field(:distribution_version, :string)

      def changeset(expected_properties, params \\ %{}) do
        expected_properties
        |> cast(params, [
          :id,
          :cpus,
          :cores,
          :vcpus,
          :memory,
          :swap,
          :system,
          :architecture,
          :os_family,
          :distribution,
          :distribution_release,
          :distribution_version
        ])
      end
    end
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{
      app_username: "archidep"
    }
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :class_id,
      :app_username
    ])
    |> cast_embed(:expected_properties, with: &__MODULE__.ExpectedProperties.changeset/2)
    |> validate_required([:ip_address, :username, :active, :class_id])
  end

  @spec update_changeset(Server.t(), map) :: Changeset.t(t())
  def update_changeset(server, params \\ %{}) when is_struct(server, Server) and is_map(params) do
    %__MODULE__{
      name: server.name,
      ip_address: server.ip_address,
      username: server.username,
      ssh_port: server.ssh_port,
      active: server.active,
      class_id: server.class_id,
      app_username: server.app_username,
      expected_properties: server.expected_properties
    }
    |> cast(params, [
      :name,
      :ip_address,
      :username,
      :ssh_port,
      :active,
      :app_username
    ])
    |> cast_embed(:expected_properties, with: &__MODULE__.ExpectedProperties.changeset/2)
    |> validate_required([:ip_address, :username, :active])
  end

  @spec to_create_server_data(t()) :: Types.create_server_data()
  def to_create_server_data(%__MODULE__{} = form) do
    expected_properties = form.expected_properties

    %{
      name: form.name,
      ip_address: form.ip_address,
      username: form.username,
      ssh_port: form.ssh_port,
      active: form.active,
      class_id: form.class_id,
      app_username: form.app_username,
      expected_properties: %{
        cpus: expected_properties.cpus,
        cores: expected_properties.cores,
        vcpus: expected_properties.vcpus,
        memory: expected_properties.memory,
        swap: expected_properties.swap,
        system: expected_properties.system,
        architecture: expected_properties.architecture,
        os_family: expected_properties.os_family,
        distribution: expected_properties.distribution,
        distribution_release: expected_properties.distribution_release,
        distribution_version: expected_properties.distribution_version
      }
    }
  end

  @spec to_update_server_data(t()) :: Types.update_server_data()
  def to_update_server_data(%__MODULE__{} = form) do
    expected_properties = form.expected_properties

    %{
      name: form.name,
      ip_address: form.ip_address,
      username: form.username,
      ssh_port: form.ssh_port,
      active: form.active,
      app_username: form.app_username,
      expected_properties: %{
        id: expected_properties.id,
        cpus: expected_properties.cpus,
        cores: expected_properties.cores,
        vcpus: expected_properties.vcpus,
        memory: expected_properties.memory,
        swap: expected_properties.swap,
        system: expected_properties.system,
        architecture: expected_properties.architecture,
        os_family: expected_properties.os_family,
        distribution: expected_properties.distribution,
        distribution_release: expected_properties.distribution_release,
        distribution_version: expected_properties.distribution_version
      }
    }
  end
end
