defmodule ArchiDep.Servers.Schemas.ServerGroupMember do
  use ArchiDep, :schema

  import ArchiDep.Helpers.ChangesetHelpers
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Types

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: String.t(),
          username: String.t() | nil,
          username_confirmed: boolean(),
          domain: String.t(),
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
    field(:username, :string)
    field(:username_confirmed, :boolean, default: false)
    field(:domain, :string)
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

  @spec list_members_in_server_group(UUID.t()) :: list(t())
  def list_members_in_server_group(group_id),
    do:
      Repo.all(
        from(m in __MODULE__,
          join: g in assoc(m, :group),
          left_join: o in assoc(m, :owner),
          left_join: ogm in assoc(o, :group_member),
          left_join: ogmg in assoc(ogm, :group),
          where: g.id == ^group_id,
          preload: [group: g, owner: {o, group_member: {ogm, group: ogmg}}]
        )
      )

  @spec fetch_server_group_member_for_user_account_id(UUID.t()) ::
          {:ok, t()} | {:error, :server_group_member_not_found}
  def fetch_server_group_member_for_user_account_id(id),
    do:
      from(m in __MODULE__,
        join: g in assoc(m, :group),
        join: o in assoc(m, :owner),
        where: o.id == ^id and o.group_member_id == m.id,
        preload: [group: g, owner: o]
      )
      |> Repo.one()
      |> truthy_or(:server_group_member_not_found)

  @spec fetch_server_group_member(UUID.t()) ::
          {:ok, t()} | {:error, :server_group_member_not_found}
  def fetch_server_group_member(id),
    do:
      from(m in __MODULE__,
        join: g in assoc(m, :group),
        left_join: o in assoc(m, :owner),
        left_join: ogm in assoc(o, :group_member),
        left_join: ogmg in assoc(ogm, :group),
        where: m.id == ^id,
        preload: [group: g, owner: {o, group_member: {ogm, group: ogmg}}]
      )
      |> Repo.one()
      |> truthy_or(:server_group_member_not_found)

  @spec refresh!(t(), map()) :: t()
  def refresh!(
        %__MODULE__{
          id: id,
          group: %ServerGroup{id: group_id, version: group_version},
          owner: %ServerOwner{id: owner_id, version: owner_version},
          version: current_version
        } = member,
        %__MODULE__{
          id: id,
          name: name,
          username: username,
          username_confirmed: username_confirmed,
          domain: domain,
          active: active,
          group: %ServerGroup{id: group_id, version: group_version},
          owner: %ServerOwner{id: owner_id, version: owner_version},
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      member
      | name: name,
        username: username,
        username_confirmed: username_confirmed,
        domain: domain,
        active: active,
        version: version,
        updated_at: updated_at
    }
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(
        %__MODULE__{
          id: id,
          group: %ServerGroup{id: group_id, version: group_version},
          owner: %ServerOwner{id: owner_id, version: owner_version},
          version: current_version
        } = member,
        %{
          id: id,
          name: name,
          domain: domain,
          active: active,
          class: %{id: group_id, version: group_version},
          user: %{id: owner_id, version: owner_version},
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      member
      | name: name,
        domain: domain,
        active: active,
        version: version,
        updated_at: updated_at
    }
  end

  def refresh!(%__MODULE__{id: id, version: current_version} = student, %{
        id: id,
        version: version
      })
      when version <= current_version do
    student
  end

  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_server_group_member} = fetch_server_group_member(id)
    fresh_server_group_member
  end

  @spec configure_changeset(t(), Types.server_group_member_config()) :: Changeset.t()
  def configure_changeset(%__MODULE__{} = member, data) do
    now = DateTime.utc_now()

    member
    |> cast(data, [:username])
    |> change(username_confirmed: true)
    |> validate_required([:username])
    |> change(updated_at: now)
    |> optimistic_lock(:version)
    # Username
    |> update_change(:username, &trim/1)
    |> validate_length(:username, max: 20, message: "must be at most {count} characters long")
    |> validate_format(:username, ~r/\A[a-z][\-a-z0-9]*\z/i,
      message:
        "must contain only letters (without accents), numbers and hyphens, and start with a letter"
    )
    |> unique_constraint(:username, name: :students_username_unique)
    |> unsafe_validate_username_unique(member.id, member.group_id)
  end

  defp unsafe_validate_username_unique(changeset, id, group_id),
    do:
      unsafe_validate_unique_query(changeset, :username, Repo, fn changeset ->
        username = get_field(changeset, :username)

        from(m in __MODULE__,
          where:
            m.id != ^id and m.group_id == ^group_id and
              fragment("LOWER(?)", m.username) == fragment("LOWER(?)", ^username)
        )
      end)
end
