defmodule ArchiDep.Accounts.Schemas.Identity.SwitchEduId do
  @moduledoc """
  A Switch edu-ID account that has been used to log in to the application. A
  user account is created automatically the first time a Switch edu-ID account
  is used to log in. Further logins with the same Switch edu-ID account will
  update the user account with the latest information from the Switch edu-ID
  service.
  """

  use ArchiDep, :schema

  alias ArchiDep.Accounts.Types

  @derive {Inspect, only: [:id, :first_name, :last_name, :swiss_edu_person_unique_id, :version]}
  @primary_key {:id, :binary_id, []}
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          swiss_edu_person_unique_id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          used_at: DateTime.t()
        }

  schema "switch_edu_ids" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:swiss_edu_person_unique_id, :string)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    field(:used_at, :utc_datetime_usec)
  end

  @doc """
  Returns the event stream for the specified Switch edu-ID entity.
  """
  @spec event_stream(String.t() | t()) :: String.t()
  def event_stream(id) when is_binary(id), do: "accounts:switch-edu-id:#{id}"
  def event_stream(%__MODULE__{id: id}), do: event_stream(id)

  @doc """
  Creates a new Switch edu-ID identity from the specified data, or updates an
  existing identity if one already exists with the same unique identifier.
  """
  @spec create_or_update(Types.switch_edu_id_login_data(), DateTime.t()) :: Changeset.t()
  def create_or_update(%{swiss_edu_person_unique_id: swiss_edu_person_unique_id} = data, now) do
    if existing_switch_edu_id =
         Repo.get_by(__MODULE__, swiss_edu_person_unique_id: swiss_edu_person_unique_id) do
      existing_switch_edu_id
      |> cast(data, [:first_name, :last_name])
      |> touch_if_data_changed(now)
      |> change(used_at: now)
      |> optimistic_lock(:version)
      |> validate()
    else
      id = UUID.generate()

      %__MODULE__{}
      |> cast(data, [:first_name, :last_name, :swiss_edu_person_unique_id])
      |> change(id: id, version: 1, created_at: now, updated_at: now, used_at: now)
      |> validate()
    end
  end

  defp validate(changeset),
    do:
      changeset
      |> validate_required([
        :id,
        :swiss_edu_person_unique_id,
        :version,
        :created_at,
        :updated_at,
        :used_at
      ])
      |> unique_constraint(:swiss_edu_person_unique_id, name: :switch_edu_ids_unique_sepui_index)

  defp touch_if_data_changed(changeset, updated_at) do
    if changed?(changeset, :first_name) or changed?(changeset, :last_name) do
      change(changeset, updated_at: updated_at)
    else
      changeset
    end
  end
end
