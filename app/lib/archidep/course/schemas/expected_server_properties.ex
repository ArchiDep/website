defmodule ArchiDep.Course.Schemas.ExpectedServerProperties do
  @moduledoc """
  The properties that a server is expected to have when it is created for a
  course. This data is used to detect problems with the configuration of a
  server by a student (e.g. the server is not large enough because it has too
  little memory, or is too costly because it has too many CPUs).
  """
  use ArchiDep, :schema

  alias ArchiDep.Course.Types

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

  @spec blank?(t()) :: boolean()
  def blank?(%__MODULE__{
        hostname: nil,
        machine_id: nil,
        cpus: nil,
        cores: nil,
        vcpus: nil,
        memory: nil,
        swap: nil,
        system: nil,
        architecture: nil,
        os_family: nil,
        distribution: nil,
        distribution_release: nil,
        distribution_version: nil
      }),
      do: true

  def blank?(%__MODULE__{}), do: false

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

  @spec update(t(), Types.expected_server_properties()) :: Changeset.t(t())
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
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 32_767,
        message: "must be between 1 and {number}"
      )
      |> validate_number(:cores,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 32_767,
        message: "must be between 1 and {number}"
      )
      |> validate_number(:vcpus,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 32_767,
        message: "must be between 1 and {number}"
      )
      |> validate_number(:memory,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 2_147_483_647,
        message: "must be between 1 and {number}"
      )
      |> validate_number(:swap,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 2_147_483_647,
        message: "must be between 1 and {number}"
      )
      |> validate_length(:system, max: 50)
      |> validate_length(:architecture, max: 20)
      |> validate_length(:os_family, max: 50)
      |> validate_length(:distribution, max: 50)
      |> validate_length(:distribution_release, max: 50)
      |> validate_length(:distribution_version, max: 20)
end
