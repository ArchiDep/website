defmodule ArchiDepWeb.Servers.ServerPropertiesForm do
  @moduledoc """
  Server properties form schema and changeset functions for updating server
  properties. This schema only validates the basic structure and types of the
  fields. Business validations are handled in the servers context.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias Ecto.Changeset

  @type t :: struct()

  @type server_properties :: %{
          hostname: String.t() | nil,
          machine_id: String.t() | nil,
          cpus: integer() | nil,
          cores: integer() | nil,
          vcpus: integer() | nil,
          memory: integer() | nil,
          swap: integer() | nil,
          system: String.t() | nil,
          architecture: String.t() | nil,
          os_family: String.t() | nil,
          distribution: String.t() | nil,
          distribution_release: String.t() | nil,
          distribution_version: String.t() | nil
        }

  @primary_key false
  embedded_schema do
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
  end

  @spec changeset(t()) :: Changeset.t(server_properties())
  @spec changeset(t(), map()) :: Changeset.t(server_properties())
  def changeset(expected_properties, params \\ %{}),
    do:
      cast(expected_properties, params, [
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

  @spec from(ExpectedServerProperties.t()) :: t()
  def from(%ExpectedServerProperties{} = properties),
    do: %__MODULE__{
      cpus: properties.cpus,
      cores: properties.cores,
      vcpus: properties.vcpus,
      memory: properties.memory,
      swap: properties.swap,
      system: properties.system,
      architecture: properties.architecture,
      os_family: properties.os_family,
      distribution: properties.distribution,
      distribution_release: properties.distribution_release,
      distribution_version: properties.distribution_version
    }

  @spec from(ServerProperties.t()) :: t()
  def from(%ServerProperties{} = properties),
    do: %__MODULE__{
      cpus: properties.cpus,
      cores: properties.cores,
      vcpus: properties.vcpus,
      memory: properties.memory,
      swap: properties.swap,
      system: properties.system,
      architecture: properties.architecture,
      os_family: properties.os_family,
      distribution: properties.distribution,
      distribution_release: properties.distribution_release,
      distribution_version: properties.distribution_version
    }

  @spec to_data(t()) :: server_properties()
  def to_data(form), do: Map.from_struct(form)
end
