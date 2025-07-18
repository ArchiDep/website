defmodule ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :id,
    :hostname,
    :machine_id,
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
  ]
  defstruct [
    :id,
    :hostname,
    :machine_id,
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
  ]

  @type t :: %__MODULE__{
          id: UUID.t(),
          hostname: String.t() | nil,
          machine_id: String.t() | nil,
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

  @spec new(ExpectedServerProperties.t()) :: t()
  def new(properties) do
    %ExpectedServerProperties{
      id: id,
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
    } = properties

    %__MODULE__{
      id: id,
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
  end

  defimpl Event do
    alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated

    def event_stream(%ClassExpectedServerPropertiesUpdated{id: id}),
      do: "classes:#{id}"

    def event_type(_event), do: :"archidep/course/class-expected-server-properties-updated"
  end
end
