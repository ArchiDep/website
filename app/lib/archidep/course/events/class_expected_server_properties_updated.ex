defmodule ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated do
  @moduledoc false

  use ArchiDep, :event

  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias Ecto.UUID

  @derive Jason.Encoder

  @enforce_keys [
    :class,
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
    :class,
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
          class: %{
            id: UUID.t(),
            name: String.t()
          },
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

  @spec new(ExpectedServerProperties.t(), Class.t()) :: t()
  def new(properties, class) do
    %ExpectedServerProperties{
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

    %Class{
      id: class_id,
      name: class_name
    } = class

    %__MODULE__{
      class: %{id: class_id, name: class_name},
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

    @spec event_stream(ClassExpectedServerPropertiesUpdated.t()) :: String.t()
    def event_stream(%ClassExpectedServerPropertiesUpdated{class: %{id: class_id}}),
      do: "course:classes:#{class_id}"

    @spec event_type(ClassExpectedServerPropertiesUpdated.t()) :: atom()
    def event_type(_event), do: :"archidep/course/class-expected-server-properties-updated"
  end
end
