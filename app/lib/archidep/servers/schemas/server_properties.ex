defmodule ArchiDep.Servers.Schemas.ServerProperties do
  @moduledoc """
  The properties of a server, such as its hardware specifications and operating
  system details. This schema is used both to store the configured expected
  properties of a server and the detected actual properties of a server that the
  application has connected to.
  """

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

  @spec blank(UUID.t()) :: t()
  def blank(id), do: %__MODULE__{id: id}

  @spec refresh(t(), map()) :: t()
  def refresh(%__MODULE__{id: id} = properties, %{
        id: id,
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
      }),
      do: %__MODULE__{
        properties
        | hostname: hostname,
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

  @spec blank_changeset(UUID.t()) :: Changeset.t(t())
  def blank_changeset(id),
    do:
      %__MODULE__{}
      |> change(id: id)
      |> validate()

  @spec new(t(), UUID.t(), Types.server_properties()) :: Changeset.t(t())
  def new(server_properties, id, data),
    do:
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

  @spec update(t(), Types.server_properties()) :: Changeset.t(t())
  def update(server_properties, data),
    do:
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

  @spec update_from_ansible_facts(t(), map) :: Changeset.t(t())
  def update_from_ansible_facts(server_properties, facts),
    do:
      server_properties
      |> cast(
        %{
          hostname: facts["ansible_hostname"],
          machine_id: facts["ansible_machine_id"],
          cpus: facts["ansible_processor_count"],
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
        # Clear out any fields that have errors because we are going to save
        # this changeset to the database even in the presence of errors. We'll
        # just clear out the invalid fields.
        changeset.errors
        |> Keyword.keys()
        |> Enum.uniq()
        |> Enum.reduce(changeset, &put_change(&2, &1, nil))
      end)

  # TODO: adapt minimum and allow/deny "*" depending on the context
  defp validate(changeset),
    do:
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
      |> validate_number(:cpus,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 32_767,
        message: "must be between 0 and {number}"
      )
      |> validate_number(:cores,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 32_767,
        message: "must be between 0 and {number}"
      )
      |> validate_number(:vcpus,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 32_767,
        message: "must be between 0 and {number}"
      )
      |> validate_number(:memory,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 2_147_483_647,
        message: "must be between 0 and {number}"
      )
      |> validate_number(:swap,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 2_147_483_647,
        message: "must be between 0 and {number}"
      )
      |> validate_length(:system, max: 50)
      |> validate_length(:architecture, max: 20)
      |> validate_length(:os_family, max: 50)
      |> validate_length(:distribution, max: 50)
      |> validate_length(:distribution_release, max: 50)
      |> validate_length(:distribution_version, max: 20)

  @spec merge(t(), t()) :: t()
  def merge(properties, overrides),
    do: %__MODULE__{
      properties
      | hostname: merge_property(properties, overrides, :hostname),
        machine_id: merge_property(properties, overrides, :machine_id),
        cpus: merge_property(properties, overrides, :cpus),
        cores: merge_property(properties, overrides, :cores),
        vcpus: merge_property(properties, overrides, :vcpus),
        memory: merge_property(properties, overrides, :memory),
        swap: merge_property(properties, overrides, :swap),
        system: merge_property(properties, overrides, :system),
        architecture: merge_property(properties, overrides, :architecture),
        os_family: merge_property(properties, overrides, :os_family),
        distribution: merge_property(properties, overrides, :distribution),
        distribution_release: merge_property(properties, overrides, :distribution_release),
        distribution_version: merge_property(properties, overrides, :distribution_version)
    }

  @spec set_default_hostname(t(), String.t()) :: t()
  def set_default_hostname(properties, nil), do: properties

  def set_default_hostname(%__MODULE__{hostname: nil} = properties, default_hostname),
    do: %__MODULE__{properties | hostname: default_hostname}

  def set_default_hostname(properties, _default_hostname), do: properties

  defp merge_property(properties, overrides, property),
    do: merge_property(Map.get(properties, property), Map.get(overrides, property))

  defp merge_property(value, nil), do: value
  defp merge_property(value, "*") when is_binary(value), do: nil
  defp merge_property(value, 0) when is_integer(value), do: nil
  defp merge_property(_value, override), do: override

  @spec detect_mismatches(t(), t()) :: list({atom(), term(), term()})
  def detect_mismatches(expected_properties, actual_properties),
    do:
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
      |> Enum.reduce([], fn property, acc ->
        expected = expected_properties |> Map.get(property) |> trim_binary_to_nil()
        actual = actual_properties |> Map.get(property) |> trim_binary_to_nil()

        case detect_mismatch(property, expected, actual) do
          :ok ->
            acc

          {:error, {expected, actual}} ->
            [{property, expected, actual} | acc]
        end
      end)
      |> Enum.reverse()

  defp trim_binary_to_nil(value) when is_binary(value), do: trim_to_nil(value)
  defp trim_binary_to_nil(value), do: value

  defp detect_mismatch(property, nil, _actual) when is_atom(property), do: :ok

  defp detect_mismatch(property, _expected, nil) when is_atom(property), do: :ok

  defp detect_mismatch(property, 0, _actual) when is_atom(property), do: :ok

  defp detect_mismatch(property, "*", _actual) when is_atom(property), do: :ok

  defp detect_mismatch(property, expected, expected) when is_atom(property), do: :ok

  defp detect_mismatch(property, expected, actual)
       when property in [:memory, :swap] and expected != 0 do
    difference = abs(expected - actual)
    ratio = difference / expected

    if ratio > 0.1 do
      {:error, {expected, actual}}
    else
      :ok
    end
  end

  defp detect_mismatch(_property, expected, actual), do: {:error, {expected, actual}}
end
