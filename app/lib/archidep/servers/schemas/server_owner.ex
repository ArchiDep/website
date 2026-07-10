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
          counters: ServerOwnerCounters.t() | nil | NotLoaded.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "user_accounts" do
    field(:username, :string)
    field(:root, :boolean)
    field(:active, :boolean)
    belongs_to(:group_member, ServerGroupMember, source: :student_id)
    has_one(:counters, ServerOwnerCounters, foreign_key: :user_account_id, references: :id)
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

  # An owner with no counters row has never registered a server, so its counts
  # are zero. A `NotLoaded` association is a forgotten preload, not a zero
  # count, so it is left to raise rather than silently reporting the limits as
  # unmet.

  @spec active_server_count(t()) :: non_neg_integer()
  def active_server_count(%__MODULE__{
        counters: %ServerOwnerCounters{active_server_count: count}
      }),
      do: count

  def active_server_count(%__MODULE__{counters: nil}), do: 0

  @spec server_count(t()) :: non_neg_integer()
  def server_count(%__MODULE__{counters: %ServerOwnerCounters{server_count: count}}), do: count
  def server_count(%__MODULE__{counters: nil}), do: 0

  @spec active_server_limit_reached?(t()) :: boolean()
  def active_server_limit_reached?(%__MODULE__{counters: %ServerOwnerCounters{} = counters}),
    do: ServerOwnerCounters.active_server_limit_reached?(counters)

  def active_server_limit_reached?(%__MODULE__{counters: nil}), do: false

  @spec server_limit_reached?(t()) :: boolean()
  def server_limit_reached?(%__MODULE__{counters: %ServerOwnerCounters{} = counters}),
    do: ServerOwnerCounters.server_limit_reached?(counters)

  def server_limit_reached?(%__MODULE__{counters: nil}), do: false

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
