defmodule ArchiDep.Servers.ServerTracking.ServerTracker do
  @moduledoc """
  Tracks the real-time state of servers in the system. It listens to changes in
  the server states and notifies interested parties.
  """

  use GenServer

  require Logger
  import ArchiDep.Helpers.PipeHelpers
  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias Ecto.UUID
  alias Phoenix.PubSub
  alias Phoenix.Tracker

  @pubsub ArchiDep.PubSub
  @tracker ArchiDep.Tracker

  @type server_state_update :: {:server_state, UUID.t(), ServerRealTimeState.t() | nil}

  @spec start_link(list(Server.t())) :: GenServer.on_start()
  def start_link(servers) when is_list(servers),
    do: GenServer.start_link(__MODULE__, {self(), Enum.map(servers, & &1.id)})

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(server),
    do: GenServer.start_link(__MODULE__, {self(), [server.id]})

  # Client API

  @spec track(pid(), Server.t()) :: server_state_update()
  def track(tracker, server), do: GenServer.call(tracker, {:track, server.id})

  @spec untrack(pid(), Server.t()) :: server_state_update()
  def untrack(tracker, server), do: GenServer.call(tracker, {:untrack, server.id})

  @spec server_state_map(list(Server.t())) :: %{UUID.t() => ServerRealTimeState.t()}
  def server_state_map(servers), do: servers |> Enum.map(& &1.id) |> get_current_server_states()

  @spec update_server_state_map(
          %{UUID.t() => ServerRealTimeState.t()},
          server_state_update()
        ) :: %{UUID.t() => ServerRealTimeState.t()}
  def update_server_state_map(map, {:server_state, id, new_server_state}),
    do: Map.put(map, id, new_server_state)

  @spec get_current_server_state(Server.t() | UUID.t()) :: ServerRealTimeState.t() | nil

  def get_current_server_state(%Server{id: server_id}), do: get_current_server_state(server_id)

  def get_current_server_state(server_id),
    do:
      @tracker
      |> Tracker.list("servers")
      |> Enum.find(fn {key, _meta} -> key == server_id end)
      |> (case do
            {^server_id, %{state: %ServerRealTimeState{} = server_state}} -> server_state
            nil -> nil
          end)

  # Server callbacks

  @impl true
  def init({from, server_ids}) do
    Logger.debug("Init server tracker for server(s): #{inspect(server_ids)}")

    {:ok, {from, server_ids}, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, {from, server_ids}) do
    set_process_label(__MODULE__)

    :ok = PubSub.subscribe(@pubsub, "tracker:servers")

    server_ids
    |> get_current_server_states()
    |> pair(from)
    |> noreply()
  end

  @impl true
  def handle_call({:track, server_id}, {from, _tag}, {from, server_states}) do
    current_state = get_current_server_state(server_id)

    server_states
    |> Map.put(server_id, current_state)
    |> pair(from)
    |> reply_with({:server_state, server_id, current_state})
  end

  @impl true
  def handle_call({:untrack, server_id}, {from, _tag}, {from, server_states}) do
    server_states
    |> Map.delete(server_id)
    |> pair(from)
    |> reply_with({:server_state, server_id, nil})
  end

  @impl true
  def handle_info(
        {action, server_id, %{state: %ServerRealTimeState{} = server_state}},
        {from, server_states} = state
      )
      when action in [:join, :update] do
    if Map.has_key?(server_states, server_id) do
      old_server_state = Map.get(server_states, server_id)

      if more_recent_server_state?(old_server_state, server_state) do
        send(from, {:server_state, server_id, server_state})
        Map.put(server_states, server_id, server_state)
      else
        server_states
      end
      |> pair(from)
      |> noreply()
    else
      noreply(state)
    end
  end

  @impl true
  def handle_info(
        {:leave, server_id, %{state: %ServerRealTimeState{}}},
        {from, server_states} = state
      ) do
    if Map.has_key?(server_states, server_id) and Map.get(server_states, server_id) != nil do
      send(from, {:server_state, server_id, nil})

      server_states
      |> Map.put(server_id, nil)
      |> pair(from)
      |> noreply()
    else
      noreply(state)
    end
  end

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
