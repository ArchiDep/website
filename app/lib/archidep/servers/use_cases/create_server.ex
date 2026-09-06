defmodule ArchiDep.Servers.UseCases.CreateServer do
  @moduledoc false

  use ArchiDep, :use_case

  import Authentication, only: [root?: 1]
  alias ArchiDep.Clock
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerOwnerCounters
  alias ArchiDep.Servers.Types

  @spec validate_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_group_not_found}
  def validate_server(auth, group_id, data) do
    with :ok <- validate_uuid(group_id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(group_id),
         owner = ServerOwner.fetch_authenticated(auth),
         :ok <- authorize(auth, Policy, :servers, :validate_server, {data, group, owner}) do
      {:ok, new_server(auth, data, group, owner, Clock.now())}
    else
      {:error, {:access_denied, :servers, :validate_server}} ->
        {:error, :server_group_not_found}

      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}
    end
  end

  @spec create_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, {:server_limit_reached, pos_integer()}}
          | {:error, :server_group_not_found}
  def create_server(auth, group_id, data) do
    with :ok <- validate_uuid(group_id, :server_group_not_found),
         {:ok, group} <- ServerGroup.fetch_server_group(group_id),
         owner = ServerOwner.fetch_authenticated(auth),
         :ok <- authorize(auth, Policy, :servers, :create_server, {data, group, owner}) do
      case Multi.new()
           |> Multi.insert(:server, new_server(auth, data, group, owner, Clock.now()))
           |> increment_server_count(owner, group.id)
           |> Multi.merge(&increase_active_server_count(&1.server_limit, &1.server))
           |> Multi.insert(:stored_event, &server_created(auth, &1.server))
           |> Repo.transaction() do
        {:ok, %{server: server, stored_event: event}} ->
          :ok = PubSub.publish_server_created(event.data, StoredEvent.to_reference(event))
          {:ok, server}

        {:error, :server, changeset, _changes} ->
          {:error, changeset}
      end
    else
      {:error, {:access_denied, :servers, :create_server}} ->
        {:error, :server_group_not_found}

      {:error, :server_group_not_found} ->
        {:error, :server_group_not_found}
    end
  end

  defp new_server(auth, data, group, owner, now) do
    if root?(auth) do
      Server.new(data, group, owner, now)
    else
      Server.new_group_member_server(data, owner, now)
    end
  end

  # The counters row exists for every owner who already has a server in the
  # group; an owner registering their first server in it has none yet, so create
  # it. An owner enrolled again in a new class starts from a fresh row there,
  # leaving the counts of the class that has ended alone.
  defp increment_server_count(multi, %ServerOwner{} = owner, group_id) do
    case ServerOwner.counters_in_group(owner, group_id) do
      nil ->
        Multi.insert(
          multi,
          :server_limit,
          ServerOwnerCounters.initial_changeset(owner.id, group_id)
        )

      %ServerOwnerCounters{} = counters ->
        Multi.update(
          multi,
          :server_limit,
          ServerOwnerCounters.update_server_count(counters, 1)
        )
    end
  end

  defp increase_active_server_count(%ServerOwnerCounters{} = counters, %Server{active: true}),
    do:
      Multi.update(
        Multi.new(),
        :active_server_limit,
        ServerOwnerCounters.update_active_server_count(counters, 1)
      )

  defp increase_active_server_count(_counters, _server), do: Multi.new()

  defp server_created(auth, server),
    do:
      server
      |> ServerCreated.new()
      |> new_event(auth, occurred_at: server.created_at)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
