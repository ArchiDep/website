defmodule ArchiDep.Servers.Schemas.ServerGroupMember do
  use ArchiDep, :schema

  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          suggested_username: String.t(),
          username: String.t() | nil,
          active: boolean(),
          group: ServerGroup.t() | NotLoaded,
          group_id: UUID.t(),
          owner: ServerOwner.t() | nil | NotLoaded,
          owner_id: UUID.t() | nil,
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "students" do
    field(:name, :string)
    field(:suggested_username, :string)
    field(:username, :string)
    field(:active, :boolean)
    belongs_to(:group, ServerGroup, source: :class_id)
    belongs_to(:owner, ServerOwner, source: :user_account_id)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: active, group: group}, now),
    do: active and ServerGroup.active?(group, now)
end
