defmodule ArchiDep.Servers.Schemas.ServerOwner do
  @moduledoc """
  The owner who registered a server with the application.
  """

  use ArchiDep, :schema

  import ArchiDep.Servers.Schemas.ServerGroup, only: [where_server_group_active: 2]
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Errors.ServerOwnerNotFoundError
  alias ArchiDep.Servers.Schemas.ServerGroupMember

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          username: String.t() | nil,
          root: boolean(),
          active: boolean(),
          group_member: ServerGroupMember.t() | nil | NotLoaded.t(),
          group_member_id: UUID.t() | nil,
          active_server_count: non_neg_integer(),
          active_server_count_lock: pos_integer(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @active_server_limit 1

  schema "user_accounts" do
    field(:username, :string)
    field(:root, :boolean)
    field(:active, :boolean)
    belongs_to(:group_member, ServerGroupMember, source: :student_id)
    field(:active_server_count, :integer)
    field(:active_server_count_lock, :integer)
    field(:version, :integer)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @spec active?(t(), DateTime.t()) :: boolean
  def active?(%__MODULE__{active: true, root: true, group_member: nil}, _now), do: true

  def active?(
        %__MODULE__{active: true, group_member: group_member},
        now
      ),
      do: ServerGroupMember.active?(group_member, now)

  def active?(%__MODULE__{}, _now), do: false

  @spec active_server_limit() :: pos_integer()
  def active_server_limit, do: @active_server_limit

  @spec where_server_owner_active(Date.t()) :: Queryable.t()
  def where_server_owner_active(day),
    do:
      dynamic(
        [owner: o, owner_group_member: gm, owner_group: g],
        o.active and
          ((o.root and is_nil(gm)) or
             (not o.root and not is_nil(gm) and gm.active and
                ^where_server_group_active(:owner_group, day)))
      )

  @spec fetch_authenticated(Authentication.t()) :: t()
  def fetch_authenticated(auth) do
    case Repo.one(
           from(so in __MODULE__,
             left_join: gm in assoc(so, :group_member),
             left_join: gmg in assoc(gm, :group),
             left_join: gmgesp in assoc(gmg, :expected_server_properties),
             where: so.id == ^auth.principal_id,
             preload: [group_member: {gm, group: {gmg, expected_server_properties: gmgesp}}]
           )
         ) do
      nil ->
        raise ServerOwnerNotFoundError

      server_owner ->
        server_owner
    end
  end

  @spec fetch_server_owner(UUID.t()) :: {:ok, t()} | {:error, :server_owner_not_found}
  def fetch_server_owner(id),
    do:
      from(o in __MODULE__,
        left_join: gm in assoc(o, :group_member),
        left_join: gmg in assoc(gm, :group),
        left_join: gmgesp in assoc(gmg, :expected_server_properties),
        where: o.id == ^id,
        preload: [group_member: {gm, group: {gmg, expected_server_properties: gmgesp}}]
      )
      |> Repo.one()
      |> truthy_or(:server_owner_not_found)

  @spec active_server_limit_reached?(t()) :: boolean()
  def active_server_limit_reached?(%__MODULE__{active_server_count: count}),
    do: count >= @active_server_limit

  @spec update_active_server_count(t(), -1 | 1) :: Changeset.t(t())
  def update_active_server_count(owner, n) when n == -1 or n == 1,
    do:
      owner
      |> cast(%{active_server_count: owner.active_server_count + n}, [:active_server_count])
      |> optimistic_lock(:active_server_count_lock)

  @spec refresh!(t(), map()) :: t()
  def refresh!(
        %__MODULE__{
          id: id,
          group_member: %ServerGroupMember{id: group_member_id} = group_member,
          version: current_version
        } = owner,
        %{
          id: id,
          student: %{id: group_member_id} = student,
          version: version,
          updated_at: updated_at
        }
      )
      when version == current_version + 1 do
    %__MODULE__{
      owner
      | group_member: ServerGroupMember.refresh!(group_member, student),
        version: version,
        updated_at: updated_at
    }
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(%__MODULE__{id: id, version: current_version} = user, %{
        id: id,
        version: version
      })
      when version <= current_version do
    user
  end

  @spec refresh!(t(), map()) :: t()
  def refresh!(%__MODULE__{id: id}, %{id: id}) do
    {:ok, fresh_server_owner} = fetch_server_owner(id)
    fresh_server_owner
  end
end
