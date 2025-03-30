defmodule ArchiDep.Helpers.UseCaseHelpers do
  @moduledoc """
  Helper functions to implement business use cases.
  """

  import ArchiDep.Authentication, only: [is_authentication: 1]
  alias Ecto.Changeset
  alias Ecto.Multi
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Authentication
  alias ArchiDep.Events.Registry
  alias ArchiDep.Events.Store.StoredEvent

  @doc """
  Ensures that the specified limit is not too large.
  """
  @spec validate_limit(pos_integer()) :: pos_integer()
  def validate_limit(limit) when is_integer(limit) and limit >= 1 and limit <= 1000, do: limit

  @doc """
  Builds a changeset of a new business event for the specified data,
  representing the creation of the specified entity.
  """
  @spec new_creation_event(struct, Authentication.t() | map, %{
          :created_at => DateTime.t(),
          optional(atom()) => any()
        }) :: StoredEvent.changeset(struct)
  def new_creation_event(data, meta_or_auth, entity),
    do: new_event(data, meta_or_auth, occurred_at: entity.created_at)

  @doc """
  Builds a changeset of a new business event for the specified data,
  representing an update of the specified entity.
  """
  @spec new_update_event(struct, Authentication.t() | map, %{
          :updated_at => DateTime.t(),
          optional(atom()) => any()
        }) :: StoredEvent.changeset(struct)
  def new_update_event(data, meta_or_auth, entity),
    do: new_event(data, meta_or_auth, occurred_at: entity.updated_at)

  @doc """
  Builds a changeset of a new business event for the specified data.
  """
  @spec new_event(struct, Authentication.t() | map, StoredEvent.options()) ::
          StoredEvent.changeset(struct)
  def new_event(data, meta_or_auth, opts \\ [])

  def new_event(data, auth, opts)
      when is_struct(data) and is_authentication(auth) and is_list(opts) do
    data |> StoredEvent.new(%{}, opts) |> initiated_by(auth.principal)
  end

  def new_event(data, meta, opts)
      when is_struct(data) and is_map(meta) and not is_struct(meta) and is_list(opts) do
    StoredEvent.new(data, meta, opts)
  end

  @doc """
  Changes a business event to be added to an event stream without changing the
  version.
  """
  @spec add_to_stream(StoredEvent.changeset(struct), %{
          :version => pos_integer,
          optional(atom) => any
        }) ::
          StoredEvent.changeset(struct)
  def add_to_stream(changeset, %{version: version})
      when is_struct(changeset, Changeset) and is_integer(version) and version >= 1 do
    data = Changeset.get_field(changeset, :data)

    StoredEvent.stream(changeset, Registry.event_stream(data), version, Registry.event_type(data))
  end

  @doc """
  Marks a business event as initiated by the specified user account.
  """
  @spec initiated_by(StoredEvent.changeset(struct), UserAccount.t()) ::
          StoredEvent.changeset(struct)
  def initiated_by(changeset, user_account) when is_struct(user_account, UserAccount) do
    initiator = UserAccount.event_stream(user_account)
    StoredEvent.initiated_by(changeset, initiator)
  end

  @doc """
  Adds a function to run as part of an `Ecto.Multi`. The function is passed the
  changes so far.
  """
  @spec run_changes(Multi.t(), atom, (Multi.changes() -> {:ok | :error, any()})) ::
          Multi.t()
  def run_changes(multi, name, fun)
      when is_struct(multi, Multi) and is_atom(name) and is_function(fun, 1),
      do: Multi.run(multi, name, fn _repo, changes_so_far -> fun.(changes_so_far) end)
end
