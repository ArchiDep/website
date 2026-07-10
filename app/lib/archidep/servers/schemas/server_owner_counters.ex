defmodule ArchiDep.Servers.Schemas.ServerOwnerCounters do
  @moduledoc """
  Per-owner tallies of how many servers a server owner has registered, and how
  many of those are active. Owned and written by the Servers context, keyed by
  the `user_account_id` of the owning account.

  The counts back the per-owner server and active-server limits enforced when
  registering or activating a server. Each counter carries its own optimistic
  lock (`server_count_lock` / `active_server_count_lock`) so concurrent
  registrations are serialized and cannot push a count past its limit.
  """

  use ArchiDep, :schema

  @active_server_limit 1
  @server_limit 5

  @primary_key {:user_account_id, :binary_id, []}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          user_account_id: UUID.t(),
          active_server_count: non_neg_integer(),
          active_server_count_lock: pos_integer(),
          server_count: non_neg_integer(),
          server_count_lock: pos_integer()
        }

  schema "server_owner_counters" do
    field(:active_server_count, :integer)
    field(:active_server_count_lock, :integer)
    field(:server_count, :integer)
    field(:server_count_lock, :integer)
  end

  @spec active_server_limit() :: pos_integer()
  def active_server_limit, do: @active_server_limit

  @spec server_limit() :: pos_integer()
  def server_limit, do: @server_limit

  @spec active_server_limit_reached?(t()) :: boolean()
  def active_server_limit_reached?(%__MODULE__{active_server_count: count}),
    do: count >= @active_server_limit

  @spec server_limit_reached?(t()) :: boolean()
  def server_limit_reached?(%__MODULE__{server_count: count}),
    do: count >= @server_limit

  @doc """
  Changeset that creates the counters row for an owner's first server: one
  server, not yet active, with both optimistic locks starting at 1.
  """
  @spec initial_changeset(UUID.t()) :: Changeset.t(t())
  def initial_changeset(user_account_id),
    do:
      change(%__MODULE__{user_account_id: user_account_id}, %{
        active_server_count: 0,
        active_server_count_lock: 1,
        server_count: 1,
        server_count_lock: 1
      })

  @spec update_active_server_count(t(), -1 | 1) :: Changeset.t(t())
  def update_active_server_count(%__MODULE__{active_server_count: count} = counters, n)
      when n == -1 or n == 1,
      do:
        counters
        |> cast(%{active_server_count: count + n}, [:active_server_count])
        |> optimistic_lock(:active_server_count_lock)

  @spec update_server_count(t(), -1 | 1) :: Changeset.t(t())
  def update_server_count(%__MODULE__{server_count: count} = counters, n)
      when n == -1 or n == 1,
      do:
        counters
        |> cast(%{server_count: count + n}, [:server_count])
        |> optimistic_lock(:server_count_lock)
end
