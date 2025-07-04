defmodule ArchiDep.Servers.Schemas.ServerProperties do
  use ArchiDep, :schema

  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
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
        }

  schema "server_properties" do
    field(:hostname, :string)
    field(:machine_id, :string)
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

  @spec new(t(), UUID.t(), Types.server_properties()) :: Changeset.t(t())
  def new(server_properties, id, data) do
    server_properties
    |> change(id: id)
    |> cast(data, [
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
    ])
    |> validate()
  end

  @spec update(t(), Types.server_properties()) :: Changeset.t(t())
  def update(server_properties, data) do
    server_properties
    |> cast(data, [
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
    ])
    |> validate()
  end

  @spec update_from_ansible_facts(t(), map) :: Changeset.t(t())
  def update_from_ansible_facts(server_properties, facts) do
    server_properties
    |> cast(
      %{
        hostname: facts["ansible_hostname"],
        machine_id: facts["ansible_machine_id"],
        cpus: facts["ansible_processor_cores"],
        cores: facts["ansible_processor_cores"],
        vcpus: facts["ansible_processor_vcpus"],
        memory: get_in(facts, ["ansible_memory_mb", "real", "total"]),
        swap: get_in(facts, ["ansible_memory_mb", "swap", "total"]),
        system: facts["ansible_system"],
        architecture: facts["ansible_architecture"],
        os_family: facts["ansible_os_family"],
        distribution: facts["ansible_distribution"],
        distribution_release: facts["ansible_distribution_release"],
        distribution_version: facts["ansible_distribution_version"]
      },
      [
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
    )
    |> then(fn changeset ->
      changeset.errors
      |> Keyword.keys()
      |> Enum.uniq()
      |> Enum.reduce(changeset, &put_change(&2, &1, nil))
    end)
  end

  defp validate(changeset) do
    changeset
    |> update_change(:hostname, &trim_to_nil/1)
    |> update_change(:machine_id, &trim_to_nil/1)
    |> update_change(:system, &trim_to_nil/1)
    |> update_change(:architecture, &trim_to_nil/1)
    |> update_change(:os_family, &trim_to_nil/1)
    |> update_change(:distribution, &trim_to_nil/1)
    |> update_change(:distribution_release, &trim_to_nil/1)
    |> update_change(:distribution_version, &trim_to_nil/1)
    |> validate_length(:hostname, max: 255)
    |> validate_length(:machine_id, max: 255)
    |> validate_number(:cpus, greater_than_or_equal_to: 0, less_than_or_equal_to: 32_767)
    |> validate_number(:cores,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 32_767
    )
    |> validate_number(:vcpus,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 32_767
    )
    |> validate_number(:memory,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> validate_number(:swap,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647
    )
    |> validate_length(:system, max: 50)
    |> validate_length(:architecture, max: 20)
    |> validate_length(:os_family, max: 50)
    |> validate_length(:distribution, max: 50)
    |> validate_length(:distribution_release, max: 50)
    |> validate_length(:distribution_version, max: 20)
  end
end
