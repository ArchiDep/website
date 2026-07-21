defmodule ArchiDep.Servers.ServerTracking.ServerTracker do
  @moduledoc """
  Tracks the real-time state of servers in the system. It listens to changes in
  the server states and notifies interested parties.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerTrackerClientBehaviour

  use GenServer

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Authentication
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientBehaviour
  alias ArchiDep.Servers.ServerView
  alias Ecto.UUID
  alias Phoenix.PubSub
  alias Phoenix.Tracker
  require Logger

  @pubsub ArchiDep.PubSub
  @tracker ArchiDep.Tracker

  @typedoc "Anything the tracker can read a server ID from."
  @type trackable :: Server.t() | ServerView.t()

  @typedoc """
  Which servers a self-managing tracker watches on its own: all of an owner's
  servers, only an owner's active servers, or every server of a group.
  """
  @type scope :: :all | :active | {:group, UUID.t()}

  @type server_state_update :: {:server_state, UUID.t(), ServerRealTimeState.t() | nil}

  @impl ServerTrackerClientBehaviour
  @spec start_link(list(trackable())) :: GenServer.on_start()
  def start_link(servers) when is_list(servers),
    do: GenServer.start_link(__MODULE__, {self(), Enum.map(servers, & &1.id), nil, nil})

  @spec start_link(trackable()) :: GenServer.on_start()
  def start_link(server),
    do: GenServer.start_link(__MODULE__, {self(), [server.id], nil, nil})

  @impl ServerTrackerClientBehaviour
  @spec start_link(Authentication.t(), list(trackable()), scope()) :: GenServer.on_start()
  def start_link(%Authentication{principal_id: owner_id}, servers, scope)
      when is_list(servers) and scope in [:all, :active],
      do:
        GenServer.start_link(
          __MODULE__,
          {self(), servers |> in_scope(scope) |> Enum.map(& &1.id), scope, {:owner, owner_id}}
        )

  def start_link(%Authentication{}, servers, {:group, group_id}) when is_list(servers),
    do:
      GenServer.start_link(
        __MODULE__,
        {self(), Enum.map(servers, & &1.id), :all, {:group, group_id}}
      )

  # Client API

  @impl ServerTrackerClientBehaviour
  @spec track(pid(), trackable()) :: server_state_update()
  def track(tracker, server), do: GenServer.call(tracker, {:track, server.id})

  @impl ServerTrackerClientBehaviour
  @spec untrack(pid(), trackable()) :: server_state_update()
  def untrack(tracker, server), do: GenServer.call(tracker, {:untrack, server.id})

  @impl ServerTrackerClientBehaviour
  @spec server_state_map(list(trackable())) :: %{UUID.t() => ServerRealTimeState.t()}
  def server_state_map(servers), do: servers |> Enum.map(& &1.id) |> get_current_server_states()

  @impl ServerTrackerClientBehaviour
  @spec update_server_state_map(
          %{UUID.t() => ServerRealTimeState.t() | nil},
          server_state_update()
        ) :: %{UUID.t() => ServerRealTimeState.t() | nil}
  def update_server_state_map(map, {:server_state, id, new_server_state}),
    do: Map.put(map, id, new_server_state)

  @impl ServerTrackerClientBehaviour
  @spec get_current_server_state(Server.t() | UUID.t()) :: ServerRealTimeState.t() | nil

  def get_current_server_state(%Server{id: server_id}) do
    get_current_server_state(server_id)
  end

  def get_current_server_state(server_id) do
    tracked =
      @tracker
      |> Tracker.list("servers")
      |> Enum.find(fn {key, _meta} -> key == server_id end)

    case tracked do
      {^server_id, %{state: %ServerRealTimeState{} = server_state}} -> server_state
      nil -> nil
    end
  end

  # Server callbacks

  @impl GenServer
  def init({from, server_ids, scope, subscription}) do
    Logger.debug("Init server tracker for server(s): #{inspect(server_ids)}")

    {:ok, {from, server_ids, scope, subscription}, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, {from, server_ids, scope, subscription}) do
    set_process_label(__MODULE__)

    :ok = PubSub.subscribe(@pubsub, "tracker:servers")

    # In a self-managing mode the tracker maintains its own tracked set: it
    # listens to the relevant server lifecycle (an owner's or a group's) and
    # tracks/untracks servers autonomously, so the web layer never orchestrates
    # tracking or names those topics.
    subscribe_to_lifecycle(subscription)

    server_ids
    |> get_current_server_states()
    |> with_scope(from, scope)
    |> noreply()
  end

  @impl GenServer
  def handle_call({:track, server_id}, {from, _tag}, {from, server_states, scope}) do
    current_state = get_current_server_state(server_id)

    server_states
    |> Map.put(server_id, current_state)
    |> with_scope(from, scope)
    |> reply_with({:server_state, server_id, current_state})
  end

  @impl GenServer
  def handle_call({:untrack, server_id}, {from, _tag}, {from, server_states, scope}) do
    server_states
    |> Map.delete(server_id)
    |> with_scope(from, scope)
    |> reply_with({:server_state, server_id, nil})
  end

  @impl GenServer
  def handle_info(
        {action, server_id, %{state: %ServerRealTimeState{} = server_state}},
        {from, server_states, scope} = state
      )
      when action in [:join, :update] do
    if Map.has_key?(server_states, server_id) do
      old_server_state = Map.get(server_states, server_id)

      new_server_states =
        if more_recent_server_state?(old_server_state, server_state) do
          send(from, {:server_state, server_id, server_state})
          Map.put(server_states, server_id, server_state)
        else
          server_states
        end

      new_server_states
      |> with_scope(from, scope)
      |> noreply()
    else
      noreply(state)
    end
  end

  @impl GenServer
  def handle_info(
        {:leave, server_id, %{state: %ServerRealTimeState{}}},
        {from, server_states, scope} = state
      ) do
    if Map.has_key?(server_states, server_id) and Map.get(server_states, server_id) != nil do
      send(from, {:server_state, server_id, nil})

      server_states
      |> Map.put(server_id, nil)
      |> with_scope(from, scope)
      |> noreply()
    else
      noreply(state)
    end
  end

  @impl GenServer
  def handle_info({:server_created, %{id: server_id} = event, _reference}, state),
    do: state |> reconcile_tracked(server_id, in_scope?(state, event)) |> noreply()

  @impl GenServer
  def handle_info({:server_updated, %{id: server_id} = event, _reference}, state),
    do: state |> reconcile_tracked(server_id, in_scope?(state, event)) |> noreply()

  @impl GenServer
  def handle_info({:server_deleted, %{id: server_id}, _reference}, state),
    do: state |> reconcile_tracked(server_id, false) |> noreply()

  # Bring the tracked set in line with whether a server should be watched:
  # start tracking a newly-relevant server, stop tracking one that dropped out
  # of scope or was deleted, and leave an unchanged membership untouched.
  defp reconcile_tracked({from, server_states, scope}, server_id, should_track) do
    case {should_track, Map.has_key?(server_states, server_id)} do
      {true, false} ->
        current_state = get_current_server_state(server_id)
        send(from, {:server_state, server_id, current_state})
        {from, Map.put(server_states, server_id, current_state), scope}

      {false, true} ->
        send(from, {:server_state, server_id, nil})
        {from, Map.delete(server_states, server_id), scope}

      _unchanged ->
        {from, server_states, scope}
    end
  end

  defp subscribe_to_lifecycle(nil), do: :ok

  defp subscribe_to_lifecycle({:owner, owner_id}),
    do: :ok = ArchiDep.Servers.PubSub.subscribe_server_owner_servers(owner_id)

  defp subscribe_to_lifecycle({:group, group_id}),
    do: :ok = ArchiDep.Servers.PubSub.subscribe_server_group_servers(group_id)

  defp in_scope?({_from, _server_states, :all}, _event), do: true
  defp in_scope?({_from, _server_states, :active}, %{active: active}), do: active
  defp in_scope?({_from, _server_states, nil}, _event), do: false

  defp in_scope(servers, :all), do: servers
  defp in_scope(servers, :active), do: Enum.filter(servers, & &1.active)

  defp with_scope(server_states, from, scope), do: {from, server_states, scope}

  defp more_recent_server_state?(nil, %ServerRealTimeState{}), do: true

  defp more_recent_server_state?(
         %ServerRealTimeState{version: old_version},
         %ServerRealTimeState{version: new_version}
       )
       when new_version > old_version,
       do: true

  defp more_recent_server_state?(
         %ServerRealTimeState{},
         %ServerRealTimeState{}
       ),
       do: false

  defp get_current_server_states(server_ids) when is_list(server_ids) do
    server_ids_set = MapSet.new(server_ids)

    @tracker
    |> Tracker.list("servers")
    |> Enum.filter(fn {key, _meta} -> MapSet.member?(server_ids_set, key) end)
    |> Enum.reduce(%{}, fn {key, %{state: %ServerRealTimeState{} = server_state}}, acc ->
      Map.put(acc, key, server_state)
    end)
  end
end
