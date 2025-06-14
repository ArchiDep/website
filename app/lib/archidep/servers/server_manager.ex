defmodule ArchiDep.Servers.ServerManager do
  use GenServer

  require Logger
  import ArchiDep.Helpers.PipeHelpers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerConnection
  alias ArchiDep.Servers.ServerManagerState
  alias Ecto.UUID

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id) when is_binary(server_id), do: {:global, {:server_manager, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  @spec connection_idle(UUID.t(), pid()) :: :ok
  def connection_idle(server_id, connection_pid),
    do: GenServer.cast(name(server_id), {:connection_idle, connection_pid})

  # Server callbacks

  @impl true
  def init(server_id), do: {:ok, server_id, {:continue, :init}}

  @impl true
  def handle_continue(:init, server_id),
    do:
      server_id
      |> ServerManagerState.init()
      |> execute_actions()
      |> noreply()

  @impl true
  def handle_cast({:connection_idle, connection_pid}, state) do
    Process.monitor(connection_pid)

    state
    |> ServerManagerState.connection_idle(connection_pid)
    |> execute_actions()
    |> noreply()
  end

  @impl true
  def handle_info(
        {task_ref, result},
        state
      ),
      do:
        state
        |> ServerManagerState.handle_task_result(task_ref, result)
        |> execute_actions()
        |> noreply()

  # {:ok, facts} = Ansible.gather_facts(server)
  # "app-user" |> Ansible.run_playbook(server) |> Stream.run()

  def handle_info(
        {:load_average, connection_ref, result},
        state
      ),
      do:
        state
        |> ServerManagerState.receive_load_average(connection_ref, result)
        |> execute_actions()
        |> noreply()

  def handle_info(
        {:DOWN, _ref, :process, connection_pid, reason},
        state
      ),
      do:
        state
        |> ServerManagerState.connection_crashed(connection_pid, reason)
        |> execute_actions()
        |> noreply()

  defp execute_actions(%ServerManagerState{actions: [action | remaining_actions]} = state) do
    %ServerManagerState{state | actions: remaining_actions}
    |> execute_action(action)
    |> execute_actions()
  end

  defp execute_actions(%ServerManagerState{actions: []} = state) do
    state
  end

  defp execute_action(state, {:connect, factory}) do
    factory.(state, fn host, port, username, options ->
      Task.async(fn ->
        ServerConnection.connect(
          state.server,
          host,
          port,
          username,
          options
        )
      end)
    end)
  end

  defp execute_action(state, {:demonitor, ref}) do
    Process.demonitor(ref, [:flush])
    state
  end

  defp execute_action(state, {:gather_facts, factory}) do
    factory.(state, fn username ->
      Task.async(fn -> Ansible.gather_facts(state.server, username) end)
    end)
  end

  defp execute_action(state, {:request_load_average, ref}) do
    :ok = ServerConnection.ping_load_average(state.server, ref)
    state
  end

  defp execute_action(state, {:run_command, factory}) do
    factory.(state, fn command, timeout ->
      Task.async(fn -> ServerConnection.run_command(state.server, command, timeout) end)
    end)
  end

  defp execute_action(state, {:run_playbook, factory}) do
    factory.(state, fn playbook, username, vars ->
      Task.async(fn -> Ansible.run_playbook(playbook, state.server, username, vars) end)
    end)
  end

  defp execute_action(state, {:track, topic, key, value}) do
    {:ok, _ref} =
      Phoenix.Tracker.track(ArchiDep.Tracker, self(), topic, key, value)

    state
  end
end
