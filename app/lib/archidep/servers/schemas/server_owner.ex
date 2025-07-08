defmodule ArchiDep.Servers.Schemas.ServerOwner do
  @moduledoc """
  The owner of a server.
  """

  use ArchiDep, :schema

  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Errors.ServerOwnerNotFoundError

  @primary_key {:id, :binary_id, []}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: UUID.t(),
          active_server_count: non_neg_integer(),
          active_server_count_lock: pos_integer()
        }

  @active_server_limit 2

  schema "user_accounts" do
    field(:active_server_count, :integer)
    field(:active_server_count_lock, :integer)
  end

  @spec active_server_limit() :: pos_integer()
  def active_server_limit, do: @active_server_limit

  @spec fetch_authenticated(Authentication.t()) :: t()
  def fetch_authenticated(auth) do
    case Repo.one(from(so in __MODULE__, where: so.id == ^auth.principal.id)) do
      nil ->
        raise ServerOwnerNotFoundError

      server_owner ->
        server_owner
    end
  end

  @spec active_server_limit_reached?(t()) :: boolean()
  def active_server_limit_reached?(%__MODULE__{active_server_count: count}),
    do: count >= @active_server_limit

  @spec update_active_server_count(t(), -1 | 1) :: Changeset.t(t())
  def update_active_server_count(owner, n) when n == -1 or n == 1,
    do:
      owner
      |> cast(%{active_server_count: owner.active_server_count + n}, [:active_server_count])
      |> optimistic_lock(:active_server_count_lock)
end
