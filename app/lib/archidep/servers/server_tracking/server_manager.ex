defmodule ArchiDep.Servers.ServerTracking.ServerManager do
  @moduledoc """
  Manager of a specific server, responsible for handling its state, performing
  actions like connecting and running commands. The actual connection is
  abstracted by the sibling `ArchiDep.Servers.ServerTracking.ServerConnection`
  process.
  """

  use GenServer

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDep.Servers.Helpers
  alias ArchiDep.Authentication
  alias ArchiDep.Course
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Http
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.Types
  alias Ecto.Changeset
  alias Ecto.UUID
  require Logger

  @type server_manager_option :: {:state, ServerManagerBehaviour.t()}
  @type server_manager_options :: list(server_manager_option())

  @tracker ArchiDep.Tracker

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id) when is_binary(server_id), do: {:global, {__MODULE__, server_id}}

  @spec child_spec({UUID.t(), Pipeline.t(), server_manager_options()}) :: Supervisor.child_spec()
  def child_spec({server_id, pipeline, opts}),
    do: %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [server_id, pipeline, opts]},
      restart: :transient,
      significant: true
    }

  @spec start_link(UUID.t(), Pipeline.t(), server_manager_options()) :: GenServer.on_start()
  def start_link(server_id, pipeline, opts),
    do: GenServer.start_link(__MODULE__, {server_id, pipeline, opts}, name: name(server_id))

  # Client API

  @spec online?(Server.t()) :: boolean()
  def online?(server), do: GenServer.call(name(server), :online?)

  @spec connection_idle(UUID.t(), pid()) :: :ok
  def connection_idle(server_id, connection_pid),
    do: GenServer.cast(name(server_id), {:connection_idle, connection_pid})

  @spec ansible_playbook_event(AnsiblePlaybookRun.t(), AnsiblePlaybookEvent.t()) :: :ok
  def ansible_playbook_event(run, event),
    do: GenServer.cast(name(run.server), {:ansible_playbook_event, run.id, event.task_name})

  @spec ansible_playbook_completed(AnsiblePlaybookRun.t()) :: :ok
  def ansible_playbook_completed(run),
    do: GenServer.call(name(run.server), {:ansible_playbook_completed, run.id})

  @spec retry_connecting(Server.t() | UUID.t()) :: :ok
  def retry_connecting(server), do: GenServer.call(name(server), :retry_connecting)

  @spec retry_ansible_playbook(Server.t(), String.t()) ::
          :ok | {:error, :server_not_connected} | {:error, :server_busy}
  def retry_ansible_playbook(server, playbook),
    do: GenServer.call(name(server), {:retry_ansible_playbook, playbook})

  @spec retry_checking_open_ports(Server.t()) ::
          :ok | {:error, :server_not_connected} | {:error, :server_busy}
  def retry_checking_open_ports(server),
    do: GenServer.call(name(server), :retry_checking_open_ports)

  @spec update_server(Server.t(), Authentication.t(), Types.server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  def update_server(server, auth, data),
    do: GenServer.call(name(server), {:update_server, auth, data})

  @spec delete_server(Server.t(), Authentication.t()) :: :ok | {:error, :server_busy}
  def delete_server(server, auth), do: GenServer.call(name(server), {:delete_server, auth})

  @spec notify_server_up(UUID.t(), StoredEvent.t(map())) :: :ok
  def notify_server_up(server_id, event),
    do: GenServer.cast(name(server_id), {:retry_connecting, event.id})

  # Server callbacks

  @impl GenServer
  def init({server_id, pipeline, opts}),
    do: {:ok, {server_id, pipeline, opts}, {:continue, :init}}

  @impl GenServer
  def handle_continue(:init, {server_id, pipeline, opts}) do
    set_process_label(__MODULE__, server_id)

    state_factory = Keyword.fetch!(opts, :state)
    state_module = state_factory.()

    state =
      server_id
      |> state_module.init(pipeline)
      |> execute_actions()

    # TODO: watch user account & student for changes (also remove superfluous
    # reloads in update & delete server use cases once done)
    :ok = Course.PubSub.subscribe_class(state.server.group_id)

    state
    |> pair(state_module)
    |> noreply()
  end

  @impl GenServer

  def handle_cast({:connection_idle, connection_pid}, {state_module, state}),
    do:
      state
      |> state_module.connection_idle(connection_pid)
      |> execute_actions()
      |> pair(state_module)
      |> noreply()

  def handle_cast({:retry_connecting, event_id}, {state_module, state}),
    do:
      state
      |> state_module.retry_connecting({:event, event_id})
      |> execute_actions()
      |> pair(state_module)
      |> noreply()

  def handle_cast({:ansible_playbook_event, run_id, ongoing_task}, {state_module, state}),
    do:
      state
      |> state_module.ansible_playbook_event(run_id, ongoing_task)
      |> execute_actions()
      |> pair(state_module)
      |> noreply()

  @impl GenServer

  def handle_call(:online?, _from, {state_module, state}),
    do:
      state
      |> state_module.online?()
      |> reply({state_module, state})

  def handle_call({:ansible_playbook_completed, run_id}, _from, {state_module, state}),
    do:
      state
      |> state_module.ansible_playbook_completed(run_id)
      |> execute_actions()
      |> pair(state_module)
      |> reply_with(:ok)

  def handle_call(:retry_connecting, _from, {state_module, state}),
    do:
      state
      |> state_module.retry_connecting(:manual)
      |> execute_actions()
      |> pair(state_module)
      |> reply_with(:ok)

  def handle_call(
        {:retry_ansible_playbook, playbook},
        _from,
        {state_module, state}
      )
      when is_binary(playbook) do
    {new_state, result} = state_module.retry_ansible_playbook(state, playbook)

    new_state
    |> execute_actions()
    |> pair(state_module)
    |> reply_with(result)
  end

  def handle_call(:retry_checking_open_ports, _from, {state_module, state}) do
    {new_state, result} = state_module.retry_checking_open_ports(state)

    new_state
    |> execute_actions()
    |> pair(state_module)
    |> reply_with(result)
  end

  def handle_call(
        {:update_server, auth, data},
        _from,
        {state_module, state}
      ) do
    {new_state, result} = state_module.update_server(state, auth, data)

    new_state
    |> execute_actions()
    |> pair(state_module)
    |> reply_with(result)
  end

  def handle_call(
        {:delete_server, auth},
        _from,
        {state_module, state}
      ) do
    {new_state, result} = state_module.delete_server(state, auth)

    case result do
      {:error, :server_busy} ->
        new_state
        |> execute_actions()
        |> pair(state_module)
        |> reply_with(result)

      :ok ->
        {:stop, :shutdown, :ok, {state_module, new_state}}
    end
  end

  @impl GenServer

  def handle_info(:retry_connecting, {state_module, state}),
    do:
      state
      |> state_module.retry_connecting(:automated)
      |> execute_actions()
      |> pair(state_module)
      |> noreply()

  def handle_info(
        {task_ref, result},
        {state_module, state}
      )
      when is_reference(task_ref),
      do:
        state
        |> state_module.handle_task_result(
          task_ref,
          result
        )
        |> execute_actions()
        |> pair(state_module)
        |> noreply()

  def handle_info(
        {:class_updated, class},
        {state_module, state}
      ),
      do:
        state
        |> state_module.group_updated(class)
        |> execute_actions()
        |> pair(state_module)
        |> noreply()

  def handle_info({:server_manager_message, message}, {state_module, state}) do
    state
    |> state_module.on_message(message)
    |> execute_actions()
    |> pair(state_module)
    |> noreply()
  end

  def handle_info(
        {:DOWN, _ref, :process, connection_pid, reason},
        {state_module, state}
      ),
      do:
        state
        |> state_module.connection_crashed(connection_pid, reason)
        |> execute_actions()
        |> pair(state_module)
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

  defp execute_action(state, {:check_open_ports, factory}) do
    factory.(state, fn ip_address, ports ->
      Task.async(fn -> check_ports_open(ip_address, ports) end)
    end)
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

  defp execute_action(state, {:monitor, pid}) do
    Process.monitor(pid)
    state
  end

  defp execute_action(state, :notify_server_offline) do
    :ok = AnsiblePipelineQueue.server_offline(state.pipeline, state.server)
    state
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

  defp execute_action(state, {:send_message, factory}) do
    factory.(state, fn message, milliseconds ->
      Process.send_after(self(), {:server_manager_message, message}, milliseconds)
    end)
  end

  defp execute_action(state, {:track, topic, key, real_time_state}) do
    {:ok, _ref} =
      Phoenix.Tracker.track(@tracker, self(), topic, key, %{state: real_time_state})

    state
  end

  defp execute_action(state, {:update_tracking, topic, value_fn}) do
    {real_time_state, new_state} = value_fn.(state)

    {:ok, _ref} =
      Phoenix.Tracker.update(@tracker, self(), topic, state.server.id, %{
        state: real_time_state
      })

    new_state
  end

  defp check_ports_open(ip_address, ports) do
    results =
      ports
      |> Enum.map(fn port ->
        Task.async(fn -> check_port_open(ip_address, port) end)
      end)
      |> Task.await_many(30_000)
      |> Enum.filter(fn result -> result != :ok end)

    if results == [] do
      :ok
    else
      {:error, results}
    end
  end

  defp check_port_open(ip_address, port) do
    case Http.get("http://#{:inet.ntoa(ip_address)}:#{port}",
           connect_options: [timeout: 10_000],
           retry_log_level: :debug,
           max_retries: 1
         ) do
      {:ok, _res} -> :ok
      {:error, reason} -> {port, reason}
    end
  end
end
