defmodule ArchiDep.Servers.Schemas.ServerOwner do
  @moduledoc """
  The owner who registered a server with the application.

  This is a read-view of the `user_accounts` table owned (written) by the
  Accounts context.
  """

  use ArchiDep, :schema

  import ArchiDep.Servers.Schemas.ServerGroup, only: [where_server_group_active: 2]
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Errors.ServerOwnerNotFoundError
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwnerCounters

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
          counters: list(ServerOwnerCounters.t()) | NotLoaded.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_accounts" do
    field(:username, :string)
    field(:root, :boolean)
    field(:active, :boolean)
    belongs_to(:group_member, ServerGroupMember, source: :student_id)
    has_many(:counters, ServerOwnerCounters, foreign_key: :user_account_id, references: :id)
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
             left_join: c in assoc(so, :counters),
             where: so.id == ^auth.principal_id,
             preload: [
               group_member: {gm, group: {gmg, expected_server_properties: gmgesp}},
               counters: c
             ]
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
        left_join: c in assoc(o, :counters),
        where: o.id == ^id,
        preload: [
          group_member: {gm, group: {gmg, expected_server_properties: gmgesp}},
          counters: c
        ]
      )
      |> Repo.one()
      |> truthy_or(:server_owner_not_found)

  # The quotas are per owner *per class*: an owner keeps their account when they
  # enrol again, and the servers of the class that has ended are kept, so the
  # only counts that may hold a registration back are the ones for the class
  # being registered in. An owner with no counters row for that class has never
  # registered a server in it, so its counts are zero. A `NotLoaded` association
  # is a forgotten preload, not a zero count, so it is left to raise rather than
  # silently reporting the limits as unmet.

  @spec counters_in_group(t(), UUID.t()) :: ServerOwnerCounters.t() | nil
  def counters_in_group(%__MODULE__{counters: counters}, group_id) when is_list(counters),
    do: Enum.find(counters, &(&1.class_id == group_id))

  @spec active_server_count(t(), UUID.t()) :: non_neg_integer()
  def active_server_count(%__MODULE__{} = owner, group_id) do
    case counters_in_group(owner, group_id) do
      %ServerOwnerCounters{active_server_count: count} -> count
      nil -> 0
    end
  end

  @spec server_count(t(), UUID.t()) :: non_neg_integer()
  def server_count(%__MODULE__{} = owner, group_id) do
    case counters_in_group(owner, group_id) do
      %ServerOwnerCounters{server_count: count} -> count
      nil -> 0
    end
  end

  @spec active_server_limit_reached?(t(), UUID.t()) :: boolean()
  def active_server_limit_reached?(%__MODULE__{} = owner, group_id) do
    case counters_in_group(owner, group_id) do
      %ServerOwnerCounters{} = counters ->
        ServerOwnerCounters.active_server_limit_reached?(counters)

      nil ->
        false
    end
  end

  @spec server_limit_reached?(t(), UUID.t()) :: boolean()
  def server_limit_reached?(%__MODULE__{} = owner, group_id) do
    case counters_in_group(owner, group_id) do
      %ServerOwnerCounters{} = counters -> ServerOwnerCounters.server_limit_reached?(counters)
      nil -> false
    end
  end
end
