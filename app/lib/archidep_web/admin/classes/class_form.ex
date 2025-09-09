defmodule ArchiDepWeb.Admin.Classes.ClassForm do
  @moduledoc """
  Class form schema and changeset functions for creating and updating class
  data. This schema only validates the basic structure and types of the fields.
  Business validations are handled in the course context.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Types
  alias Ecto.Changeset

  @type t :: struct()

  @primary_key false
  embedded_schema do
    field(:name, :string, default: "")
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean, default: false)
    field(:ssh_exercise_vm_ip_address, :string)
    field(:servers_enabled, :boolean, default: false)
  end

  @spec create_changeset(map()) :: Changeset.t(Types.class_data())
  def create_changeset(params \\ %{}) when is_map(params) do
    %__MODULE__{}
    |> cast(params, [
      :name,
      :start_date,
      :end_date,
      :active,
      :ssh_exercise_vm_ip_address,
      :servers_enabled
    ])
    |> validate_required([:name, :active, :servers_enabled])
  end

  @spec update_changeset(Class.t(), map()) :: Changeset.t(Types.class_data())
  def update_changeset(class, params \\ %{}) when is_struct(class, Class) and is_map(params) do
    %__MODULE__{
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      ssh_exercise_vm_ip_address: class.ssh_exercise_vm_ip_address,
      servers_enabled: class.servers_enabled
    }
    |> cast(params, [
      :name,
      :start_date,
      :end_date,
      :active,
      :ssh_exercise_vm_ip_address,
      :servers_enabled
    ])
    |> validate_required([:name, :active, :servers_enabled])
  end

  @spec to_class_data(t()) :: Types.class_data()
  def to_class_data(%__MODULE__{} = form), do: Map.from_struct(form)
end
