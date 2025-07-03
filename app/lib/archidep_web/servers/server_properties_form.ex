defmodule ArchiDepWeb.Servers.ServerPropertiesForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Servers.Schemas.ServerProperties

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

  def changeset(expected_properties, params \\ %{}) do
    expected_properties
    |> cast(params, [
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

  def from(%ServerProperties{} = properties) do
    %__MODULE__{
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
  end

  def to_data(form), do: Map.from_struct(form)
end
