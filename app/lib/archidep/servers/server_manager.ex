defmodule ArchiDep.Servers.ServerManager do
  use GenServer

  require Logger
  import ArchiDep.Helpers.PipeHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerConnection
  alias ArchiDep.Servers.ServerManagerState
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Class
  alias Ecto.UUID

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id) when is_binary(server_id), do: {:global, {__MODULE__, server_id}}

  @spec start_link({Server.t(), Pipeline.t()}) :: GenServer.on_start()
  def start_link({%Server{id: server_id} = server, pipeline}),
    do: GenServer.start_link(__MODULE__, {server_id, pipeline}, name: name(server))

  # Client API

  @spec online?(Server.t()) :: boolean()
  def online?(server), do: GenServer.call(name(server), :online?)

  @spec connection_idle(UUID.t(), pid()) :: :ok
  def connection_idle(server_id, connection_pid),
    do: GenServer.cast(name(server_id), {:connection_idle, connection_pid})

  @spec ansible_playbook_completed(AnsiblePlaybookRun.t()) :: :ok
  def ansible_playbook_completed(run),
    do: GenServer.call(name(run.server), {:ansible_playbook_completed, run.id})

  # Server callbacks

  @impl true
  def init({server_id, pipeline}), do: {:ok, {server_id, pipeline}, {:continue, :init}}

  @impl true
  def handle_continue(:init, {server_id, pipeline}) do
    state =
      server_id
      |> ServerManagerState.init(pipeline)
      |> execute_actions()

    :ok = Servers.PubSub.subscribe_server(state.server.id)
    :ok = Students.PubSub.subscribe_class(state.server.class.id)

    noreply(state)
  end

  @impl true
  def handle_cast({:connection_idle, connection_pid}, state) do
    Process.monitor(connection_pid)

    state
    |> ServerManagerState.connection_idle(connection_pid)
    |> execute_actions()
    |> noreply()
  end

  @impl true

  def handle_call(:online?, _from, state),
    do:
      state
      |> ServerManagerState.online?()
      |> reply(state)

  def handle_call({:ansible_playbook_completed, run_id}, _from, state),
    do:
      state
      |> ServerManagerState.ansible_playbook_completed(run_id)
      |> execute_actions()
      |> reply_with(:ok)

  @impl true

  def handle_info(:retry, state) do
    state
    |> ServerManagerState.retry_connecting()
    |> execute_actions()
    |> noreply()
  end

  def handle_info(
        {task_ref, result},
        state
      )
      when is_reference(task_ref),
      do:
        state
        |> ServerManagerState.handle_task_result(task_ref, result)
        |> execute_actions()
        |> noreply()

  def handle_info(
        {:class_updated, class},
        state
      )
      when is_struct(class, Class),
      do:
        state
        |> ServerManagerState.class_updated(class)
        |> execute_actions()
        |> noreply()

  def handle_info(
        {:server_updated, server},
        state
      )
      when is_struct(server, Server),
      do:
        state
        |> ServerManagerState.server_updated(server)
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

  defp execute_action(state, {:cancel_timer, ref}) do
    Process.cancel_timer(ref)
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

  defp execute_action(state, :notify_server_offline) do
    :ok = AnsiblePipelineQueue.server_offline(state.pipeline, state.server)
    state
  end

  defp execute_action(state, {:retry, factory}) do
    factory.(state, fn milliseconds ->
      Process.send_after(self(), :retry, milliseconds)
    end)
  end

  defp execute_action(state, {:run_command, factory}) do
    factory.(state, fn command, timeout ->
      Task.async(fn -> ServerConnection.run_command(state.server, command, timeout) end)
    end)
  end

  defp execute_action(state, {:run_playbook, playbook_run}) do
    :ok =
      AnsiblePipelineQueue.run_playbook(
        state.pipeline,
        playbook_run
      )

    state
  end

  defp execute_action(state, {:track, topic, key, value}) do
    {:ok, _ref} =
      Phoenix.Tracker.track(ArchiDep.Tracker, self(), topic, key, value)

    state
  end
end
