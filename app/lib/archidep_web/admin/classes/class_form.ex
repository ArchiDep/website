defmodule ArchiDepWeb.Admin.Classes.ClassForm do
  @moduledoc """
  Class form schema and changeset functions for creating and updating class
  data. This schema only validates the basic structure and types of the fields.
  Business validations are handled in the course context.
  """

  use Ecto.Schema

  import ArchiDepWeb.Helpers.FormHelpers, only: [tmp_boolify: 2]
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
    field(:servers_enabled, :boolean, default: false)
    embeds_many(:teacher_ssh_public_keys, ClassFormSshPublicKey, on_replace: :delete)
    field(:ssh_exercise_vm_md5_host_key_fingerprints, :string)
    field(:ssh_exercise_vm_sha256_host_key_fingerprints, :string)
  end

  @spec add_teacher_ssh_public_key(t()) :: t()
  def add_teacher_ssh_public_key(form),
    do:
      Changeset.put_embed(
        form.source,
        :teacher_ssh_public_keys,
        Changeset.get_field(form.source, :teacher_ssh_public_keys, []) ++
          [%ClassFormSshPublicKey{}]
      )

  @spec create_changeset(map()) :: Changeset.t(Types.class_data())
  def create_changeset(params \\ %{}) when is_map(params) do
    fixed_params = params |> tmp_boolify("active") |> tmp_boolify("servers_enabled")

    %__MODULE__{}
    |> cast(
      fixed_params,
      [
        :name,
        :start_date,
        :end_date,
        :active,
        :servers_enabled,
        :ssh_exercise_vm_md5_host_key_fingerprints,
        :ssh_exercise_vm_sha256_host_key_fingerprints
      ]
    )
    |> cast_embed(:teacher_ssh_public_keys, drop_param: :delete_keys)
    |> validate_required([:name, :active, :servers_enabled])
  end

  @spec update_changeset(Class.t(), map()) :: Changeset.t(Types.class_data())
  def update_changeset(class, params \\ %{}) when is_struct(class, Class) and is_map(params) do
    fixed_params = params |> tmp_boolify("active") |> tmp_boolify("servers_enabled")

    %__MODULE__{
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      teacher_ssh_public_keys:
        Enum.map(class.teacher_ssh_public_keys, &ClassFormSshPublicKey.new(&1)),
      ssh_exercise_vm_md5_host_key_fingerprints: class.ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints:
        class.ssh_exercise_vm_sha256_host_key_fingerprints
    }
    |> cast(
      fixed_params,
      [
        :name,
        :start_date,
        :end_date,
        :active,
        :servers_enabled,
        :ssh_exercise_vm_md5_host_key_fingerprints,
        :ssh_exercise_vm_sha256_host_key_fingerprints
      ]
    )
    |> cast_embed(:teacher_ssh_public_keys, drop_param: :delete_keys)
    |> validate_required([:name, :active, :servers_enabled])
  end

  @spec to_class_data(t()) :: Types.class_data()
  def to_class_data(%__MODULE__{} = form),
    do:
      form
      |> Map.from_struct()
      |> Map.delete(:teacher_ssh_public_keys)
      |> Map.put(:teacher_ssh_public_keys, to_keys_data(form.teacher_ssh_public_keys))

  defp to_keys_data([%ClassFormSshPublicKey{value: ""}]), do: []

  defp to_keys_data(teacher_ssh_public_keys), do: Enum.map(teacher_ssh_public_keys, & &1.value)
end
