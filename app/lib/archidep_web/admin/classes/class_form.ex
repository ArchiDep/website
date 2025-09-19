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
  alias ArchiDepWeb.Admin.Classes.ClassFormSshPublicKey
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
    embeds_many(:teacher_ssh_public_keys, ClassFormSshPublicKey, on_replace: :delete)
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
    |> cast_embed(:teacher_ssh_public_keys)
    |> validate_required([:name, :active, :servers_enabled])
    |> add_empty_key_if_none()
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
    |> cast_embed(:teacher_ssh_public_keys)
    |> validate_required([:name, :active, :servers_enabled])
    |> add_empty_key_if_none()
  end

  @spec to_class_data(t()) :: Types.class_data()
  def to_class_data(%__MODULE__{} = form),
    do:
      form
      |> Map.from_struct()
      |> Map.delete(:teacher_ssh_public_keys)
      |> Map.put(:teacher_ssh_public_keys, to_keys_data(form.teacher_ssh_public_keys))

  defp add_empty_key_if_none(changeset) do
    changeset
    |> get_field(:teacher_ssh_public_keys, [])
    |> case do
      [] -> put_embed(changeset, :teacher_ssh_public_keys, [%ClassFormSshPublicKey{}])
      _ -> changeset
    end
  end

  defp to_keys_data([%ClassFormSshPublicKey{value: ""}]), do: []
  defp to_keys_data(teacher_ssh_public_keys), do: Enum.map(teacher_ssh_public_keys, & &1.value)
end
