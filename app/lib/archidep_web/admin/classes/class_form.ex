defmodule ArchiDepWeb.Admin.Classes.ClassForm do
  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Types
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          expected_server_cpus: pos_integer() | nil,
          expected_server_cores: pos_integer() | nil,
          expected_server_vcpus: pos_integer() | nil,
          expected_server_memory: pos_integer() | nil,
          expected_server_swap: pos_integer() | nil,
          expected_server_system: String.t() | nil,
          expected_server_architecture: String.t() | nil,
          expected_server_os_family: String.t() | nil,
          expected_server_distribution: String.t() | nil,
          expected_server_distribution_release: String.t() | nil,
          expected_server_distribution_version: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean, default: true)
    field(:expected_server_cpus, :integer)
    field(:expected_server_cores, :integer)
    field(:expected_server_vcpus, :integer)
    field(:expected_server_memory, :integer)
    field(:expected_server_swap, :integer)
    field(:expected_server_system, :string)
    field(:expected_server_architecture, :string)
    field(:expected_server_os_family, :string)
    field(:expected_server_distribution, :string)
    field(:expected_server_distribution_release, :string)
    field(:expected_server_distribution_version, :string)
  end

  @spec create_changeset(map) :: Changeset.t(t())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [
      :name,
      :start_date,
      :end_date,
      :active,
      :expected_server_cpus,
      :expected_server_cores,
      :expected_server_vcpus,
      :expected_server_memory,
      :expected_server_swap,
      :expected_server_system,
      :expected_server_architecture,
      :expected_server_os_family,
      :expected_server_distribution,
      :expected_server_distribution_release,
      :expected_server_distribution_version
    ])
    |> validate_required([:name, :active])
  end

  @spec update_changeset(Class.t(), map) :: Changeset.t(t())
  def update_changeset(class, params \\ %{}) when is_struct(class, Class) and is_map(params) do
    %__MODULE__{
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      expected_server_cpus: class.expected_server_cpus,
      expected_server_cores: class.expected_server_cores,
      expected_server_vcpus: class.expected_server_vcpus,
      expected_server_memory: class.expected_server_memory,
      expected_server_swap: class.expected_server_swap,
      expected_server_system: class.expected_server_system,
      expected_server_architecture: class.expected_server_architecture,
      expected_server_os_family: class.expected_server_os_family,
      expected_server_distribution: class.expected_server_distribution,
      expected_server_distribution_release: class.expected_server_distribution_release,
      expected_server_distribution_version: class.expected_server_distribution_version
    }
    |> cast(params, [
      :name,
      :start_date,
      :end_date,
      :active,
      :expected_server_cpus,
      :expected_server_cores,
      :expected_server_vcpus,
      :expected_server_memory,
      :expected_server_swap,
      :expected_server_system,
      :expected_server_architecture,
      :expected_server_os_family,
      :expected_server_distribution,
      :expected_server_distribution_release,
      :expected_server_distribution_version
    ])
    |> validate_required([:name, :active])
  end

  @spec to_class_data(t()) :: Types.class_data()
  def to_class_data(%__MODULE__{} = form) do
    %{
      name: form.name,
      start_date: form.start_date,
      end_date: form.end_date,
      active: form.active,
      expected_server_cpus: form.expected_server_cpus,
      expected_server_cores: form.expected_server_cores,
      expected_server_vcpus: form.expected_server_vcpus,
      expected_server_memory: form.expected_server_memory,
      expected_server_swap: form.expected_server_swap,
      expected_server_system: form.expected_server_system,
      expected_server_architecture: form.expected_server_architecture,
      expected_server_os_family: form.expected_server_os_family,
      expected_server_distribution: form.expected_server_distribution,
      expected_server_distribution_release: form.expected_server_distribution_release,
      expected_server_distribution_version: form.expected_server_distribution_version
    }
  end
end
