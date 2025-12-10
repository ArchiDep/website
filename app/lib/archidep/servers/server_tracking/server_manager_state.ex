defmodule ArchiDep.Servers.ServerTracking.ServerManagerState do
  @moduledoc """
  The state of a server manager for a single server. It contains the server's
  connection state and various other information about the server. It is also
  responsible for determining the next actions to be performed on the server
  depending on its state.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerManagerBehaviour

  import ArchiDep.Helpers.UseCaseHelpers
  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Servers.ServerTracking.ServerProblems
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Helpers.NetHelpers
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Events.ServerConnected
  alias ArchiDep.Servers.Events.ServerDisconnected
  alias ArchiDep.Servers.Events.ServerReconnecting
  alias ArchiDep.Servers.Events.ServerRetriedAnsiblePlaybook
  alias ArchiDep.Servers.Events.ServerRetriedCheckingOpenPorts
  alias ArchiDep.Servers.Events.ServerRetriedConnecting
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias ArchiDep.Servers.Types
  alias ArchiDep.Servers.UseCases.DeleteServer
  alias ArchiDep.Servers.UseCases.UpdateServer
  alias Ecto.UUID
  alias Phoenix.Token
  require Logger
  require Record

  @enforce_keys [
    :server,
    :pipeline,
    :username
  ]
  defstruct [
    :server,
    :pipeline,
    :username,
    connection_state: not_connected_state(),
    actions: [],
    # TODO: tasks, ansible playbook and load average timer should be part of the connected state
    tasks: %{},
    ansible: nil,
    problems: [],
    # TODO: retry timer should be part of the retry connecting state
    retry_timer: nil,
    load_average_timer: nil,
    connection_timer: nil,
    version: 0
  ]

  @type t :: %__MODULE__{
          connection_state: connection_state(),
          server: Server.t(),
          pipeline: Pipeline.t(),
          username: String.t(),
          actions: list(action()),
          tasks: %{optional(atom()) => reference()},
          ansible:
            :gathering_facts
            | {AnsiblePlaybookRun.t(), String.t() | nil, EventReference.t()}
            | nil,
          problems: list(server_problem()),
          retry_timer: reference() | nil,
          load_average_timer: reference() | nil,
          connection_timer: reference() | nil,
          version: non_neg_integer()
        }

  @type network_port :: NetHelpers.network_port()

  @type connection_state :: ServerConnectionState.connection_state()

  @type cancel_timer_action :: {:cancel_timer, reference()}

  @type check_open_ports_action ::
          {:check_open_ports,
           (t(), (:inet.ip_address(), list(network_port()) -> Task.t()) -> t())}
  @type connect_action ::
          {:connect,
           (t(),
            (:inet.ip_address(), network_port(), String.t(), ServerConnection.connect_options() ->
               Task.t()) ->
              t())}
  @type demonitor_action :: {:demonitor, reference()}
  @type gather_facts_action ::
          {:gather_facts, String.t()}
  @type monitor_action :: {:monitor, pid()}
  @type notify_server_offline_action :: :notify_server_offline
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook, AnsiblePlaybookRun.t(), EventReference.t()}
  @type send_message_action ::
          {:send_message, (t(), (term(), pos_integer() -> reference()) -> t())}
  @type track_action :: {:track, String.t(), UUID.t(), ServerRealTimeState.t()}
  @type update_tracking_action :: {:update_tracking, String.t(), (t() -> {map(), t()})}
  @type action ::
          cancel_timer_action()
          | check_open_ports_action()
          | connect_action()
          | demonitor_action()
          | gather_facts_action()
          | monitor_action()
          | notify_server_offline_action()
          | run_command_action()
          | run_playbook_action()
          | send_message_action()
          | track_action()
          | update_tracking_action()

  @type server_problem :: Types.server_problem()

  @retry_intervals_seconds [
    5,
    5,
    10,
    20,
    30,
    40,
    50,
    60,
    300,
    900,
    1800,
    3600
  ]

  @last_retry_interval_seconds List.last(@retry_intervals_seconds)

  @ports_to_check [80, 443, 3000, 3001]
  @event_base [:tracking, :servers, :archidep]

  @impl ServerManagerBehaviour
  def init(server_id, pipeline) do
    Logger.debug("Init server manager for server #{server_id}")

    {:ok, server} = Server.fetch_server(server_id)

    last_setup_run =
      AnsiblePlaybookRun.get_last_playbook_run(server, Ansible.setup_playbook())

    %__MODULE__{
      server: server,
      pipeline: pipeline,
      username: user_to_connect_as(server)
    }
    |> maybe_add_problem(determine_last_setup_run_problem(last_setup_run))
    |> track()
  end

  defp determine_last_setup_run_problem(%AnsiblePlaybookRun{state: state} = last_setup_run)
       when state != :succeeded,
       do: server_ansible_playbook_failed_problem(last_setup_run)

  defp determine_last_setup_run_problem(_last_setup_run), do: nil

  @impl ServerManagerBehaviour
  def online?(%__MODULE__{connection_state: connected_state()}), do: true
  def online?(_state), do: false

  # TODO: try connecting after a while if the connection idle message is not received
  @impl ServerManagerBehaviour

  def connection_idle(
        %__MODULE__{
          connection_state: not_connected_state(connection_pid: nil),
          server: server,
          connection_timer: nil
        } = state,
        connection_pid
      ) do
    Logger.debug("Connection idle for server #{server.id}")

    if Server.active?(server, DateTime.utc_now()) do
      state
      |> change_connection_state(connection_pending_state(connection_pid: connection_pid))
      |> add_actions([
        update_tracking_action(),
        monitor_action(connection_pid),
        schedule_connection_action()
      ])
    else
      state
      |> change_connection_state(not_connected_state(connection_pid: connection_pid))
      |> add_action(monitor_action(connection_pid))
    end
  end

  def connection_idle(
        %__MODULE__{connection_state: disconnected_state(), server: server} = state,
        connection_pid
      ) do
    Logger.debug("Connection idle for server #{server.id}")

    if Server.active?(server, DateTime.utc_now()) do
      retrying = back_off_retrying(false, :disconnected)

      state
      |> change_connection_state(
        retry_connecting_state(
          connection_pid: connection_pid,
          retrying: retrying
        )
      )
      |> add_actions([
        update_tracking_action(),
        retry_action(retrying),
        monitor_action(connection_pid)
      ])
    else
      state
      |> change_connection_state(not_connected_state(connection_pid: connection_pid))
      |> add_actions([update_tracking_action(), monitor_action(connection_pid)])
    end
  end

  @impl ServerManagerBehaviour

  def retry_connecting(
        %__MODULE__{
          connection_state:
            retry_connecting_state(connection_pid: connection_pid, retrying: retrying)
        } = state,
        manual
      ),
      do:
        connect(
          state,
          connection_pid,
          # When manually retrying, the backoff counter is reset and the manager
          # restarts trying to connect more frequently, then proceeds to add the
          # usual backoff.
          maybe_manually_retry(retrying, manual),
          retry_connecting_causation_event(state, manual)
        )

  def retry_connecting(
        %__MODULE__{
          connection_state: connection_failed_state(connection_pid: connection_pid)
        } = state,
        manual
      ),
      do: connect(state, connection_pid, false, retry_connecting_causation_event(state, manual))

  def retry_connecting(state, _manual) do
    Logger.warning(
      "Ignore request to retry connecting to server #{state.server.id} in connection state #{inspect(state.connection_state)}"
    )

    state
  end

  defp retry_connecting_causation_event(_state, {:event, event}), do: event

  defp retry_connecting_causation_event(state, :manual),
    do:
      state.server
      |> ServerRetriedConnecting.new(state.username)
      |> persist_server_event!(state.server, DateTime.utc_now(), nil)
      |> StoredEvent.to_reference()

  defp retry_connecting_causation_event(_state, :automated), do: nil

  defp connect(state, connection_pid, retrying, causation_event),
    do:
      state
      |> change_connection_state(
        connecting_state(
          connection_ref: make_ref(),
          connection_pid: connection_pid,
          time: DateTime.utc_now(),
          retrying: retrying,
          causation_event: causation_event
        )
      )
      |> add_action(update_tracking_action())
      |> maybe_cancel_retry_timer()
      |> add_actions([
        connect_action(state),
        monitor_action(connection_pid)
      ])
      |> drop_problems([
        :server_missing_sudo_access,
        :server_reconnection_failed,
        :server_sudo_access_check_failed
      ])

  @impl ServerManagerBehaviour

  # Handle connection result
  def handle_task_result(
        %__MODULE__{
          connection_state:
            connecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid,
              time: start_time,
              causation_event: event
            ),
          tasks: %{connect: connection_task_ref}
        } = state,
        connection_task_ref,
        result
      ) do
    handle_connect_task_result(
      state,
      connection_ref,
      connection_pid,
      connection_task_ref,
      start_time,
      event,
      result
    )
  end

  # Handle reconnection result (after initial setup)
  def handle_task_result(
        %__MODULE__{
          connection_state:
            reconnecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid,
              time: start_time,
              causation_event: causation_event
            ),
          tasks: %{connect: connection_task_ref}
        } = state,
        connection_task_ref,
        result
      ) do
    handle_connect_task_result(
      state,
      connection_ref,
      connection_pid,
      connection_task_ref,
      start_time,
      causation_event,
      result
    )
  end

  # Handle sudo access check result
  def handle_task_result(
        %__MODULE__{connection_state: connected_state(), tasks: %{check_access: check_access_ref}} =
          state,
        check_access_ref,
        result
      ),
      do:
        state
        |> handle_access_check_result(result)
        |> drop_task(:check_access, check_access_ref)

  # Handle load average result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{get_load_average: get_load_average_ref}
        } = state,
        get_load_average_ref,
        result
      ),
      do:
        state
        |> handle_load_average_result(result)
        |> drop_task(:get_load_average, get_load_average_ref)

  # Handle test ports result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{test_ports: test_ports_ref}
        } = state,
        test_ports_ref,
        result
      ),
      do:
        state
        |> handle_port_testing_script_result(result)
        |> drop_task(:test_ports, test_ports_ref)

  # Handle check open ports result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{check_open_ports: check_open_ports_ref}
        } = state,
        check_open_ports_ref,
        result
      ),
      do:
        state
        |> handle_open_ports_check_result(result)
        |> drop_task(:check_open_ports, check_open_ports_ref)

  defp handle_connect_task_result(
         state,
         connection_ref,
         connection_pid,
         connection_task_ref,
         start_time,
         causation_event,
         result
       ),
       do:
         state
         |> handle_connect_task_result(
           connection_ref,
           connection_pid,
           start_time,
           causation_event,
           result
         )
         |> drop_task(:connect, connection_task_ref)

  defp handle_connect_task_result(
         %__MODULE__{server: server, username: username} = state,
         connection_ref,
         connection_pid,
         start_time,
         causation_event,
         :ok
       ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager is connected to server #{server.id} as #{state.username}; checking sudo access..."
    )

    now = DateTime.utc_now()
    connection_duration = DateTime.diff(now, start_time, :millisecond)

    execute_telemetry_event(:connected, %{
      duration: connection_duration / 1000
    })

    connected_event =
      server
      |> ServerConnected.new(username, connection_duration)
      |> persist_server_event!(server, now, causation_event)

    state
    |> change_connection_state(
      connected_state(
        connection_ref: connection_ref,
        connection_pid: connection_pid,
        time: DateTime.utc_now(),
        connection_event: StoredEvent.to_reference(connected_event)
      )
    )
    |> add_actions([update_tracking_action(), check_sudo_access()])
    |> drop_connection_problems()
  end

  defp handle_connect_task_result(
         %__MODULE__{server: server} = state,
         _connection_ref,
         connection_pid,
         _start_time,
         _causation_event,
         {:error, :authentication_failed}
       ) do
    Logger.warning(
      "Server manager could not connect to server #{server.id} as #{state.username} because authentication failed"
    )

    state
    |> change_connection_state(
      connection_failed_state(
        connection_pid: connection_pid,
        reason: :authentication_failed
      )
    )
    |> add_action(update_tracking_action())
    |> set_problem(server_authentication_failed_problem(server, state.username))
  end

  defp handle_connect_task_result(
         %__MODULE__{server: server} = state,
         _connection_ref,
         connection_pid,
         _start_time,
         _causation_event,
         {:error, :key_exchange_failed}
       ) do
    Logger.warning(
      "Server manager could not connect to server #{server.id} as #{state.username} because key exchange failed"
    )

    unknown_fingerprint =
      Enum.find(state.problems, fn
        {:server_key_exchange_failed, _fingerprint, _ssh_host_key_fingerprints} -> true
        _anything_else -> false
      end) || {:server_key_exchange_failed, nil, nil}

    state
    |> change_connection_state(
      connection_failed_state(
        connection_pid: connection_pid,
        reason: :key_exchange_failed
      )
    )
    |> add_action(update_tracking_action())
    |> set_problem(server_key_exchange_failed_problem(server, elem(unknown_fingerprint, 1)))
  end

  defp handle_connect_task_result(
         %__MODULE__{server: server} = state,
         _connection_ref,
         connection_pid,
         _start_time,
         _causation_event,
         {:error, reason}
       ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager could not connect to server #{server.id} as #{state.username} because #{inspect(reason)}"
    )

    case state.connection_state do
      # Move to the connection retry state on connection failure.
      connecting_state(retrying: retrying) ->
        retrying_again = back_off_retrying(retrying, reason)

        state
        |> change_connection_state(
          retry_connecting_state(
            connection_pid: connection_pid,
            retrying: retrying_again
          )
        )
        |> add_actions([update_tracking_action(), retry_action(retrying_again)])
        |> drop_connection_problems()
        |> maybe_add_problem(determine_connection_problem(state, reason))

      # Move to the connection failed state on reconnection failure. A failure
      # while reconnecting is considered a problem because reconnection happens
      # immediately after the initial setup. The server should be up and there
      # should be no reason why we cannot connect again with the application
      # user unless something is wrong.
      reconnecting_state() ->
        state
        |> change_connection_state(
          connection_failed_state(
            connection_pid: connection_pid,
            reason: reason
          )
        )
        |> add_action(update_tracking_action())
        |> set_problem(server_reconnection_failed_problem(reason))
    end
  end

  # Return a connection timeout problem for the server's normal user. A
  # connection timeout is considered a problem for the normal user because setup
  # has not yet been successfully completed.
  defp determine_connection_problem(
         %__MODULE__{username: username, server: %Server{username: username} = server},
         :timeout
       ),
       do: server_connection_timed_out_problem(server, username)

  # Return a connection refused problem for the server's app user. A refused
  # connection is considered a problem for the normal user because setup has not
  # yet been successfully completed.
  defp determine_connection_problem(
         %__MODULE__{username: username, server: %Server{username: username} = server},
         :econnrefused
       ),
       do: server_connection_refused_problem(server, username)

  # Return no problem if the connection failed for the application user. The
  # server has been set up so we don't care about connection problems which will
  # often happen when the server is shut down or rebooted.
  defp determine_connection_problem(_state, _reason), do: nil

  defp back_off_retrying(false, reason),
    do: %{
      retry: 1,
      backoff: 0,
      time: DateTime.utc_now(),
      in_seconds: List.first(@retry_intervals_seconds),
      reason: reason
    }

  defp back_off_retrying(%{retry: previous_retry, backoff: previous_backoff}, reason) do
    next_retry = previous_retry + 1
    next_backoff = previous_backoff + 1

    in_seconds =
      Enum.at(@retry_intervals_seconds, previous_backoff) || @last_retry_interval_seconds

    %{
      retry: next_retry,
      backoff: next_backoff,
      time: DateTime.utc_now(),
      in_seconds: in_seconds,
      reason: reason
    }
  end

  defp handle_access_check_result(
         %__MODULE__{
           connection_state: connected_state(),
           server: %Server{app_username: app_username},
           username: app_username
         } = state,
         {:ok, _stdout, _stderr, 0}
       ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager has sudo access to server #{state.server.id} as #{app_username}; gathering facts..."
    )

    add_actions(%__MODULE__{state | ansible: :gathering_facts}, [
      update_tracking_action(),
      get_load_average(),
      gather_facts_action(app_username)
    ])
  end

  defp handle_access_check_result(
         %__MODULE__{
           connection_state: connected_state(connection_event: connection_event),
           server: server,
           username: username
         } = state,
         {:ok, _stdout, _stderr, 0}
       ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager has sudo access to server #{server.id} as #{username}; setting up app user..."
    )

    last_setup_runs =
      AnsiblePlaybookRun.fetch_last_playbook_runs(server, Ansible.setup_playbook(), 3)

    state
    |> add_action(update_tracking_action())
    |> maybe_run_setup_playbook(last_setup_runs, connection_event)
  end

  defp handle_access_check_result(
         %__MODULE__{
           connection_state: connected_state(),
           server: server,
           username: username
         } = state,
         {:ok, _stdout, stderr, _non_zero_exit_code}
       ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager does not have sudo access to server #{server.id} as #{username}; connected with problems"
    )

    state
    |> add_actions([update_tracking_action(), get_load_average()])
    |> set_problem(server_missing_sudo_access_problem(username, stderr))
  end

  defp handle_access_check_result(
         %__MODULE__{
           connection_state: connected_state(),
           server: server,
           username: username
         } = state,
         {:error, reason}
       ) do
    Logger.warning(
      "Server manager could not check sudo access to server #{server.id} as #{username} because #{inspect(reason)}; connected with problems"
    )

    state
    |> add_actions([update_tracking_action(), get_load_average()])
    |> set_problem(server_sudo_access_check_failed_problem(username, reason))
  end

  defp handle_load_average_result(
         %__MODULE__{connection_state: connected_state()} = state,
         result
       ) do
    with {:ok, stdout, _stderr, 0} <- result,
         [m1s, m5s, m15s | _rest] <- stdout |> String.trim() |> String.split(~r/\s+/),
         [{m1, ""}, {m5, ""}, {m15, ""}] <- [
           Float.parse(m1s),
           Float.parse(m5s),
           Float.parse(m15s)
         ] do
      Logger.debug("Received load average from server #{state.server.id}: #{m1}, #{m5}, #{m15}")
    end

    add_action(state, measure_load_average_action())
  end

  defp test_ports_or_rerun_setup(%__MODULE__{server: server} = state, [], _playbook) do
    Logger.warning("No previous Ansible setup playbook run found for server #{server.id}")
    maybe_test_ports(state)
  end

  defp test_ports_or_rerun_setup(
         %__MODULE__{connection_state: connected_state(connection_event: connection_event)} =
           state,
         [
           %AnsiblePlaybookRun{
             state: :succeeded,
             playbook_digest: playbook_digest,
             vars_digest: previous_vars_digest
           }
           | _previous_runs
         ],
         %AnsiblePlaybook{digest: playbook_digest}
       ) do
    case build_setup_playbook_vars(state.server) do
      {_vars, ^previous_vars_digest} ->
        maybe_test_ports(state)

      {_vars, vars_digest} = vars_and_digest ->
        Logger.notice(
          # coveralls-ignore-next-line
          "Re-running Ansible setup playbook for server #{state.server.id} because the digest of its variables has changed from #{Base.encode16(previous_vars_digest, case: :lower)} to #{Base.encode16(vars_digest, case: :lower)}"
        )

        run_setup_playbook(state, connection_event, vars_and_digest)
    end
  end

  defp test_ports_or_rerun_setup(
         %__MODULE__{
           connection_state: connected_state(connection_event: connection_event),
           server: server
         } = state,
         [
           %AnsiblePlaybookRun{state: :succeeded, playbook_digest: previous_digest}
           | _previous_runs
         ],
         %AnsiblePlaybook{digest: digest}
       ) do
    Logger.notice(
      # coveralls-ignore-next-line
      "Re-running Ansible setup playbook for server #{server.id} because its digest has changed from #{Base.encode16(previous_digest, case: :lower)} to #{Base.encode16(digest, case: :lower)}"
    )

    run_setup_playbook(state, connection_event)
  end

  defp test_ports_or_rerun_setup(
         %__MODULE__{
           connection_state: connected_state(connection_event: connection_event),
           server: server
         } = state,
         [%AnsiblePlaybookRun{state: last_state} | _previous_runs] = last_runs,
         _playbook
       ) do
    Logger.notice(
      # coveralls-ignore-next-line
      "Re-running Ansible setup playbook for server #{server.id} because its last run did not succeed (#{inspect(last_state)})"
    )

    maybe_run_setup_playbook(state, last_runs, connection_event)
  end

  defp handle_port_testing_script_result(
         %__MODULE__{connection_state: connected_state(), server: server} = state,
         {:ok, _stdout, _stderr, 0}
       ) do
    Logger.debug("Port testing script succeeded on server #{server.id}")

    state
    |> add_actions([update_tracking_action(), check_open_ports_action(server)])
    |> drop_port_checking_problems()
  end

  defp handle_port_testing_script_result(
         %__MODULE__{connection_state: connected_state(), server: server} = state,
         {:ok, _stdout, stderr, non_zero_exit_code}
       ) do
    Logger.warning(
      "Port testing script exited with code #{non_zero_exit_code} on server #{server.id}: #{inspect(stderr)}"
    )

    state
    |> change_connection_state(connected_state(state.connection_state, retry_event: nil))
    |> add_action(update_tracking_action())
    |> drop_port_checking_problems()
    |> add_problem(server_port_testing_script_failed_problem(:exit, non_zero_exit_code, stderr))
  end

  defp handle_port_testing_script_result(
         %__MODULE__{connection_state: connected_state(), server: server} = state,
         {:error, reason}
       ) do
    Logger.error("Port testing script failed on server #{server.id} because: #{inspect(reason)}")

    state
    |> change_connection_state(connected_state(state.connection_state, retry_event: nil))
    |> add_action(update_tracking_action())
    |> drop_port_checking_problems()
    |> add_problem(server_port_testing_script_failed_problem(:error, reason))
  end

  defp handle_open_ports_check_result(
         %__MODULE__{
           connection_state: connected_state(connection_event: cause, retry_event: retry_cause),
           server: server
         } =
           state,
         :ok
       ),
       do:
         state
         |> change_connection_state(connected_state(state.connection_state, retry_event: nil))
         |> set_updated_server(maybe_mark_open_ports_checked(server, retry_cause || cause))
         |> add_action(update_tracking_action())
         |> drop_port_checking_problems()

  defp handle_open_ports_check_result(
         %__MODULE__{connection_state: connected_state()} = state,
         {:error, port_problems}
       ),
       do:
         state
         |> change_connection_state(connected_state(state.connection_state, retry_event: nil))
         |> add_action(update_tracking_action())
         |> drop_port_checking_problems()
         |> add_problem(server_open_ports_check_failed_problem(port_problems))

  defp maybe_mark_open_ports_checked(%Server{open_ports_checked_at: nil} = server, cause),
    do: Server.mark_open_ports_checked!(server, @ports_to_check, cause)

  defp maybe_mark_open_ports_checked(server, _cause), do: server

  @impl ServerManagerBehaviour

  def ansible_facts_gathered(
        %__MODULE__{
          connection_state: connected_state(connection_event: connection_event),
          ansible: :gathering_facts
        } =
          state,
        {:ok, facts}
      ) do
    Logger.debug("Gathered facts from server #{state.server.id}")

    updated_server = Server.update_last_known_properties!(state.server, facts, connection_event)

    setup_playbook = Ansible.setup_playbook()

    last_setup_runs =
      AnsiblePlaybookRun.fetch_last_playbook_runs(updated_server, setup_playbook, 3)

    state
    |> clear_current_ansible_task()
    |> set_updated_server(updated_server)
    |> add_action(update_tracking_action())
    |> detect_server_properties_mismatches()
    |> test_ports_or_rerun_setup(last_setup_runs, setup_playbook)
  end

  def ansible_facts_gathered(
        %__MODULE__{connection_state: connected_state(), ansible: :gathering_facts} = state,
        {:error, reason}
      ) do
    Logger.warning(
      "Server manager could not gather facts for server #{state.server.id} because #{inspect(reason)}"
    )

    state
    |> clear_current_ansible_task()
    |> add_action(update_tracking_action())
    |> set_problem(server_fact_gathering_failed_problem(reason))
  end

  @impl ServerManagerBehaviour

  def ansible_playbook_event(
        %__MODULE__{
          ansible: {%AnsiblePlaybookRun{id: run_id}, _previous_task, _cause}
        } = state,
        run_id,
        ongoing_task
      ) do
    state
    |> add_action(update_tracking_action())
    |> update_ongoing_playbook_task(ongoing_task)
  end

  def ansible_playbook_event(state, _run_id, _ongoing_task) do
    Logger.warning(
      "Ignoring Ansible playbook event for server #{state.server.id} because no playbook is running"
    )

    state
  end

  @impl ServerManagerBehaviour
  def ansible_playbook_completed(
        %__MODULE__{
          connection_state: connected_state(),
          ansible: {%AnsiblePlaybookRun{id: run_id, playbook: "setup"}, _task, _cause}
        } = state,
        run_id
      ) do
    server = state.server
    Logger.info("Ansible setup playbook completed for server #{server.id}")

    run = AnsiblePlaybookRun.get_completed_run!(run_id)

    state
    |> add_action(update_tracking_action())
    |> handle_ansible_playbook_completed(run)
    |> clear_current_ansible_task()
  end

  def ansible_playbook_completed(state, run_id) do
    Logger.warning(
      "Ignoring completed Ansible playbook run #{run_id} for server #{state.server.id}"
    )

    state
  end

  defp handle_ansible_playbook_completed(
         %__MODULE__{
           connection_state:
             connected_state(
               connection_pid: connection_pid,
               connection_ref: connection_ref
             ),
           server: %Server{username: username, app_username: app_username} = server,
           username: username,
           ansible: {%AnsiblePlaybookRun{id: run_id, playbook: "setup"}, _task, cause}
         } = state,
         %AnsiblePlaybookRun{id: run_id, playbook: "setup", state: :succeeded}
       ) do
    updated_server = Server.mark_as_set_up!(server, cause)

    reconnecting_event =
      updated_server
      |> ServerReconnecting.new(app_username)
      |> persist_server_event!(updated_server, DateTime.utc_now(), cause)

    state
    |> change_connection_state(
      reconnecting_state(
        connection_pid: connection_pid,
        connection_ref: connection_ref,
        time: DateTime.utc_now(),
        causation_event: StoredEvent.to_reference(reconnecting_event)
      )
    )
    |> set_updated_server(updated_server)
    |> connect_with_app_username()
    |> then(&add_action(&1, connect_action(&1)))
    |> stop_measuring_load_average()
    |> drop_problems(server_ansible_playbook_failed_problem?("setup"))
  end

  defp handle_ansible_playbook_completed(
         %__MODULE__{
           connection_state: connected_state(),
           ansible: {%AnsiblePlaybookRun{id: run_id, playbook: "setup"}, _task, _cause}
         } = state,
         %AnsiblePlaybookRun{id: run_id} = run
       ),
       do:
         state
         |> drop_problems(server_ansible_playbook_failed_problem?("setup"))
         |> maybe_add_problem(determine_ansible_playbook_problem(run))

  defp determine_ansible_playbook_problem(%AnsiblePlaybookRun{state: :succeeded}), do: nil

  defp determine_ansible_playbook_problem(failed_run),
    do: server_ansible_playbook_failed_problem(failed_run)

  @impl ServerManagerBehaviour
  def retry_ansible_playbook(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          username: username,
          problems: problems,
          tasks: tasks,
          ansible: nil
        } = state,
        "setup"
      )
      when tasks == %{} do
    has_failed_setup_playbook =
      Enum.any?(problems, server_ansible_playbook_failed_problem?("setup"))

    if has_failed_setup_playbook do
      Logger.info("Retrying Ansible setup playbook for server #{server.id}")

      retry_event =
        server
        |> ServerRetriedAnsiblePlaybook.new(username, "setup")
        |> persist_server_event!(server, DateTime.utc_now())

      state
      |> add_action(update_tracking_action())
      |> run_setup_playbook(StoredEvent.to_reference(retry_event))
      |> with_reply(:ok)
    else
      Logger.info(
        # coveralls-ignore-next-line
        "Ignoring retry request for Ansible setup playbook for server #{server.id} because there is no such failed run"
      )

      with_reply(state, :ok)
    end
  end

  def retry_ansible_playbook(%__MODULE__{connection_state: connected_state()} = state, playbook) do
    Logger.info(
      # coveralls-ignore-next-line
      "Ignoring retry request for Ansible #{playbook} playbook because the server is busy"
    )

    with_reply(state, {:error, :server_busy})
  end

  def retry_ansible_playbook(%__MODULE__{} = state, playbook) do
    Logger.info(
      # coveralls-ignore-next-line
      "Ignoring retry request for Ansible #{playbook} playbook because the server is not connected"
    )

    with_reply(state, {:error, :server_not_connected})
  end

  @impl ServerManagerBehaviour
  def retry_checking_open_ports(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          problems: problems,
          tasks: tasks,
          ansible: nil
        } = state
      )
      when tasks == %{} do
    Logger.info("Retrying checking open ports for server #{server.id}")

    has_failed_checking_open_ports =
      Enum.any?(
        problems,
        server_problem?([:server_port_testing_script_failed, :server_open_ports_check_failed])
      )

    if has_failed_checking_open_ports do
      retried_event =
        server
        |> ServerRetriedCheckingOpenPorts.new(state.username, @ports_to_check)
        |> persist_server_event!(server, DateTime.utc_now())
        |> StoredEvent.to_reference()

      state
      |> change_connection_state(
        connected_state(state.connection_state, retry_event: retried_event)
      )
      |> add_actions([update_tracking_action(), test_ports()])
      |> with_reply(:ok)
    else
      Logger.info(
        # coveralls-ignore-next-line
        "Ignoring retry request for checking open ports for server #{server.id} because there is no port checking problem"
      )

      with_reply(state, :ok)
    end
  end

  def retry_checking_open_ports(
        %__MODULE__{connection_state: connected_state(), server: server} = state
      ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Ignoring retry request for checking open ports for server #{server.id} because the server is busy"
    )

    with_reply(state, {:error, :server_busy})
  end

  def retry_checking_open_ports(%__MODULE__{server: server} = state) do
    Logger.info(
      # coveralls-ignore-next-line
      "Ignoring retry request for checking open ports for server #{server.id} because the server is not connected"
    )

    with_reply(state, {:error, :server_not_connected})
  end

  @impl ServerManagerBehaviour
  def group_updated(
        %__MODULE__{
          server: %Server{
            id: server_id,
            group: %ServerGroup{id: group_id, version: current_version} = current_group
          }
        } = state,
        %{id: group_id, version: version} = group,
        event
      ) do
    Logger.info(
      # coveralls-ignore-next-line
      "Server manager for server #{server_id} received group update from version #{current_version} to version #{version}"
    )

    new_group = ServerGroup.refresh!(current_group, group)

    if new_group == current_group do
      state
    else
      new_server = %Server{state.server | group: new_group}

      state
      |> set_updated_server(new_server, false)
      |> detect_server_properties_mismatches()
      |> auto_activate_or_deactivate(event)
    end
  end

  @impl ServerManagerBehaviour
  def connection_crashed(
        %__MODULE__{connection_state: connection_state} = state,
        connection_pid,
        reason
      ) do
    now = DateTime.utc_now()

    connected_time =
      case connection_state do
        connected_state(time: time) -> time
        _other_state -> now
      end

    execute_telemetry_event(:connection_crashed, %{
      duration: DateTime.diff(now, connected_time, :millisecond) / 1000
    })

    disconnect(state, connection_pid(connection_state), connection_pid, reason)
  end

  defp disconnect(state, connection_pid, connection_pid, reason) when is_pid(connection_pid),
    do: disconnect(state, reason)

  defp disconnect(state, _connection_pid, _disconnected_pid, reason),
    do: disconnect(state, reason)

  defp disconnect(state, reason) do
    server = state.server
    Logger.info("Connection to server #{server.id} crashed because: #{inspect(reason)}")

    case state.connection_state do
      connected_state(time: time) ->
        now = DateTime.utc_now()
        uptime = DateTime.diff(now, time, :millisecond)

        server
        |> ServerDisconnected.new(state.username, uptime, reason)
        |> persist_server_event!(server, now)

      _any_other_state ->
        :noop
    end

    state
    |> change_connection_state(disconnected_state(time: DateTime.utc_now()))
    |> add_actions([update_tracking_action(), notify_server_offline_action()])
    |> stop_measuring_load_average()
    |> maybe_cancel_connection_timer()
    |> maybe_cancel_retry_timer()
    |> drop_remaining_tasks()
    |> drop_connected_problems()
  end

  @impl ServerManagerBehaviour
  def update_server(state, auth, data) do
    case state do
      %__MODULE__{connection_state: connecting_state()} ->
        with_reply(state, {:error, :server_busy})

      %__MODULE__{connection_state: reconnecting_state()} ->
        with_reply(state, {:error, :server_busy})

      _any_other_state ->
        do_update_server(state, auth, data)
    end
  end

  defp do_update_server(state, auth, data) do
    case UpdateServer.update_server(auth, state.server, data) do
      {:ok, updated_server, event} ->
        state
        |> set_updated_server(updated_server, false)
        |> update_user_to_connect_as()
        |> detect_server_properties_mismatches()
        |> auto_activate_or_deactivate(event)
        |> with_reply({:ok, updated_server, event})

      {:error, changeset} ->
        with_reply(state, {:error, changeset})
    end
  end

  @impl ServerManagerBehaviour
  def delete_server(
        state,
        auth
      ) do
    case state do
      %__MODULE__{connection_state: not_connected_state(), tasks: tasks, ansible: nil}
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)
        with_reply(state, :ok)

      %__MODULE__{
        connection_state: connection_pending_state(connection_pid: connection_pid),
        tasks: tasks,
        ansible: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        state
        |> change_connection_state(not_connected_state(connection_pid: connection_pid))
        |> maybe_cancel_connection_timer()
        |> with_reply(:ok)

      %__MODULE__{
        connection_state: retry_connecting_state(connection_pid: connection_pid),
        tasks: tasks,
        ansible: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        state
        |> change_connection_state(not_connected_state(connection_pid: connection_pid))
        |> maybe_cancel_retry_timer()
        |> with_reply(:ok)

      %__MODULE__{
        connection_state: connected_state(connection_pid: connection_pid),
        server: server,
        tasks: tasks,
        ansible: nil
      }
      when tasks == %{} ->
        :ok = ServerConnection.disconnect(server)
        :ok = DeleteServer.delete_server(auth, server)

        state
        |> change_connection_state(not_connected_state(connection_pid: connection_pid))
        |> with_reply(:ok)

      %__MODULE__{
        connection_state: connection_failed_state(connection_pid: connection_pid),
        tasks: tasks,
        ansible: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        state
        |> change_connection_state(not_connected_state(connection_pid: connection_pid))
        |> with_reply(:ok)

      %__MODULE__{
        connection_state: disconnected_state(),
        tasks: tasks,
        ansible: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        state
        |> change_connection_state(not_connected_state())
        |> with_reply(:ok)

      _any_other_state ->
        with_reply(state, {:error, :server_busy})
    end
  end

  defp auto_activate_or_deactivate(
         %__MODULE__{connection_state: connection_state, server: server} = state,
         causation_event
       ) do
    if Server.active?(server, DateTime.utc_now()) do
      case connection_state do
        not_connected_state(connection_pid: connection_pid) when connection_pid != nil ->
          state
          |> change_connection_state(
            connection_pending_state(
              connection_pid: connection_pid,
              causation_event: causation_event
            )
          )
          |> add_actions([update_tracking_action(), schedule_connection_action()])

        _any_other_state ->
          add_action(state, update_tracking_action())
      end
    else
      state |> add_action(update_tracking_action()) |> deactivate()
    end
  end

  defp deactivate(
         %__MODULE__{
           connection_state: connection_pending_state(connection_pid: connection_pid)
         } = state
       ) do
    state
    |> maybe_cancel_connection_timer()
    |> change_connection_state(not_connected_state(connection_pid: connection_pid))
  end

  defp deactivate(
         %__MODULE__{
           connection_state: connected_state(connection_pid: connection_pid),
           server: server
         } = state
       ) do
    :ok = ServerConnection.disconnect(server.id)

    change_connection_state(state, not_connected_state(connection_pid: connection_pid))
  end

  defp deactivate(
         %__MODULE__{connection_state: retry_connecting_state(connection_pid: connection_pid)} =
           state
       ) do
    state
    |> change_connection_state(not_connected_state(connection_pid: connection_pid))
    |> maybe_cancel_retry_timer()
  end

  defp deactivate(%__MODULE__{connection_state: disconnected_state()} = state) do
    %__MODULE__{state | connection_state: not_connected_state()}
  end

  defp deactivate(
         %__MODULE__{connection_state: connection_failed_state(connection_pid: connection_pid)} =
           state
       ) do
    change_connection_state(state, not_connected_state(connection_pid: connection_pid))
  end

  defp deactivate(%__MODULE__{} = state) do
    state
  end

  @impl ServerManagerBehaviour

  def on_message(
        %__MODULE__{
          connection_state:
            connection_pending_state(
              connection_pid: connection_pid,
              causation_event: causation_event
            )
        } = state,
        :connect
      ),
      do:
        state
        |> maybe_cancel_connection_timer()
        |> connect(connection_pid, false, causation_event)

  def on_message(%__MODULE__{connection_state: connected_state()} = state, :measure_load_average),
    do: add_action(state, get_load_average())

  def on_message(%__MODULE__{server: server} = state, {:unknown_key_fingerprint, fingerprint})
      when is_binary(fingerprint),
      do:
        state
        |> drop_problems(server_key_exchange_failed_problem?())
        |> add_problem(server_key_exchange_failed_problem(server, fingerprint))

  def on_message(state, :measure_load_average) do
    Logger.warning(
      "Ignoring :measure_load_average message sent to server #{state.server.id} because the server is no longer connected"
    )

    state
  end

  def on_message(state, :retry_connecting), do: retry_connecting(state, :automated)

  defp drop_task(%__MODULE__{tasks: tasks} = state, key) do
    case Map.get(tasks, key) do
      nil ->
        state

      task_ref ->
        drop_task(state, key, task_ref)
    end
  end

  defp drop_task(%__MODULE__{actions: actions, tasks: tasks} = state, key, ref) do
    case Map.get(tasks, key) do
      ^ref ->
        %__MODULE__{
          state
          | tasks: Map.delete(tasks, key),
            actions: [demonitor_action(ref) | actions]
        }
    end
  end

  defp maybe_test_ports(%__MODULE__{server: %Server{open_ports_checked_at: nil}} = state),
    do: add_action(state, test_ports())

  defp maybe_test_ports(%__MODULE__{} = state), do: state

  defp gather_facts_action(username),
    do: {:gather_facts, username}

  defp check_open_ports_action(server),
    do:
      {:check_open_ports,
       fn task_state, task_factory ->
         task = task_factory.(server.ip_address.address, @ports_to_check)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, :check_open_ports, task.ref)
         }
       end}

  defp get_load_average, do: run_command_action(:get_load_average, "cat /proc/loadavg", 10_000)
  defp check_sudo_access, do: run_command_action(:check_access, "sudo -n ls", 20_000)

  defp test_ports,
    do:
      run_command_action(
        :test_ports,
        "sudo /usr/local/sbin/test-ports #{Enum.join(@ports_to_check, " ")}",
        10_000
      )

  defp run_command_action(name, command, timeout),
    do:
      {:run_command,
       fn task_state, task_factory ->
         task = task_factory.(command, timeout)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, name, task.ref)
         }
       end}

  defp detect_server_properties_mismatches(
         %__MODULE__{server: server, problems: problems} = state
       ),
       do: %__MODULE__{state | problems: detect_server_properties_mismatches(problems, server)}

  defp detect_server_properties_mismatches(problems, %Server{last_known_properties: nil}),
    do: Enum.reject(problems, server_problem?(:server_expected_property_mismatch))

  defp detect_server_properties_mismatches(
         problems,
         %Server{
           group: %ServerGroup{expected_server_properties: expected_server_properties},
           expected_properties: expected_properties_overrides,
           last_known_properties: last_known_properties
         } = server
       )
       when last_known_properties != nil do
    default_hostname = Server.default_hostname(server)

    expected_properties =
      expected_server_properties
      |> ServerProperties.merge(expected_properties_overrides)
      |> ServerProperties.set_default_hostname(default_hostname)

    mismatches = ServerProperties.detect_mismatches(expected_properties, last_known_properties)

    problems
    |> Enum.reject(server_problem?(:server_expected_property_mismatch))
    |> Enum.concat(
      Enum.map(mismatches, fn {property, expected, actual} ->
        {:server_expected_property_mismatch, property, expected, actual}
      end)
    )
  end

  defp maybe_add_problem(state, nil), do: state
  defp maybe_add_problem(state, problem), do: add_problem(state, problem)

  defp add_problem(state, problem), do: set_problems(state, [problem | state.problems])

  defp set_problem(state, problem), do: set_problems(state, [problem])
  defp set_problems(state, problems), do: %__MODULE__{state | problems: problems}

  defp drop_connection_problems(state),
    do:
      drop_problems(state, [
        :server_authentication_failed,
        :server_connection_timed_out,
        :server_connection_refused,
        :server_key_exchange_failed
      ])

  defp drop_connected_problems(state),
    do:
      drop_problems(state, [
        :server_port_testing_script_failed,
        :server_open_ports_check_failed,
        :server_fact_gathering_failed
      ])

  defp drop_port_checking_problems(state),
    do:
      drop_problems(state, [:server_port_testing_script_failed, :server_open_ports_check_failed])

  defp to_real_time_state(%__MODULE__{} = state) do
    server = state.server

    conn_username =
      if server.set_up_at, do: server.app_username, else: state.username

    %ServerRealTimeState{
      connection_state: state.connection_state,
      name: server.name,
      conn_params: {server.ip_address.address, server.ssh_port || 22, conn_username},
      username: server.username,
      app_username: server.app_username,
      current_job: determine_current_job(state),
      set_up_at: server.set_up_at,
      problems: state.problems,
      version: state.version
    }
  end

  defp determine_current_job(state) do
    case state do
      %{connection_state: connecting_state()} ->
        :connecting

      %{connection_state: reconnecting_state()} ->
        :reconnecting

      %{connection_state: connected_state(), tasks: %{check_access: _ref}} ->
        :checking_access

      %{connection_state: connected_state(), ansible: :gathering_facts} ->
        :gathering_facts

      %{connection_state: connected_state(), tasks: %{test_ports: _ref}} ->
        :checking_open_ports

      %{connection_state: connected_state(), tasks: %{check_open_ports: _ref}} ->
        :checking_open_ports

      %{
        connection_state: connected_state(),
        ansible: {%AnsiblePlaybookRun{id: id, playbook: playbook}, task, _cause}
      } ->
        {:running_playbook, playbook, id, task}

      _anything_else ->
        nil
    end
  end

  defp maybe_run_setup_playbook(state, last_runs, cause, vars_and_digest \\ nil) do
    failed_runs_count = Enum.count(last_runs, &(&1.state != :succeeded))

    if failed_runs_count == 3 do
      Logger.warning(
        "Not re-running Ansible setup playbook for server #{state.server.id} because it has failed 3 times"
      )

      add_problem(state, server_ansible_playbook_repeatedly_failed_problem(last_runs))
    else
      run_setup_playbook(state, cause, vars_and_digest)
    end
  end

  defp run_setup_playbook(
         state,
         cause,
         vars_and_digest \\ nil
       ) do
    {vars, vars_digest} = vars_and_digest || build_setup_playbook_vars(state.server)
    {playbook_run, start_event} = start_setup_playbook(state.server, vars, vars_digest, cause)

    add_action(
      %__MODULE__{state | ansible: {playbook_run, nil, cause}},
      run_playbook_action(playbook_run, start_event)
    )
  end

  defp update_ongoing_playbook_task(
         %__MODULE__{ansible: {playbook_run, _previous_task, cause}} = state,
         ongoing_task
       ),
       do: %__MODULE__{
         state
         | ansible: {playbook_run, ongoing_task, cause}
       }

  defp clear_current_ansible_task(state), do: %__MODULE__{state | ansible: nil}

  defp start_setup_playbook(server, vars, vars_digest, cause) do
    playbook = Ansible.setup_playbook()

    username = if server.set_up_at, do: server.app_username, else: server.username

    Tracker.track_playbook!(
      playbook,
      server,
      username,
      vars,
      vars_digest,
      cause
    )
  end

  defp build_setup_playbook_vars(server) do
    ssh_public_keys = [SSH.ssh_public_key() | server.group.ssh_public_keys_to_install]
    token = Token.sign(server.secret_key, "server auth", server.id)

    vars = %{
      "api_base_url" => api_base_url(),
      "app_user_name" => server.app_username,
      "app_user_authorized_key" => Enum.join(ssh_public_keys, "\n"),
      "server_id" => server.id,
      "server_token" => token
    }

    # Compute the digest of the variables, using the server's secret key instead
    # of the token, so that the digest remains the same even if the token
    # changes, as long as the secret key is unchanged.
    vars_digest =
      vars |> Map.put("server_token", server.secret_key) |> Ansible.digest_ansible_variables()

    {vars, vars_digest}
  end

  defp drop_problems(state, problems) when is_list(problems),
    do: drop_problems(state, &(elem(&1, 0) in problems))

  defp drop_problems(state, predicate_fn) when is_function(predicate_fn, 1),
    do: %__MODULE__{state | problems: Enum.reject(state.problems, &predicate_fn.(&1))}

  defp maybe_cancel_connection_timer(%__MODULE__{connection_timer: nil} = state), do: state

  defp maybe_cancel_connection_timer(%__MODULE__{connection_timer: timer} = state)
       when timer != nil,
       do: state |> clear_connection_timer() |> add_action(cancel_timer_action(timer))

  defp clear_connection_timer(state), do: %__MODULE__{state | connection_timer: nil}

  defp stop_measuring_load_average(state),
    do:
      state
      |> maybe_cancel_load_average_timer()
      |> drop_task(:get_load_average)

  defp maybe_cancel_load_average_timer(%__MODULE__{load_average_timer: nil} = state), do: state

  defp maybe_cancel_load_average_timer(%__MODULE__{load_average_timer: timer} = state),
    do: state |> clear_load_average_timer() |> add_action(cancel_timer_action(timer))

  defp clear_load_average_timer(state), do: %__MODULE__{state | load_average_timer: nil}

  defp maybe_cancel_retry_timer(%__MODULE__{retry_timer: nil} = state), do: state

  defp maybe_cancel_retry_timer(%__MODULE__{retry_timer: timer} = state),
    do: state |> clear_retry_timer() |> add_action(cancel_timer_action(timer))

  defp clear_retry_timer(state), do: %__MODULE__{state | retry_timer: nil}

  defp drop_remaining_tasks(state),
    do: %__MODULE__{
      state
      | tasks: %{},
        actions:
          Enum.reduce(state.tasks, state.actions, fn {_task_name, task_ref}, actions ->
            [demonitor_action(task_ref) | actions]
          end)
    }

  defp maybe_manually_retry(retrying, :automated), do: retrying
  defp maybe_manually_retry(retrying, :manual), do: %{retrying | backoff: 0}
  defp maybe_manually_retry(retrying, {:event, _event}), do: %{retrying | backoff: 0}

  defp change_connection_state(state, connection_state),
    do: %__MODULE__{state | connection_state: connection_state}

  defp set_updated_server(%__MODULE__{server: server} = state, server), do: state

  defp set_updated_server(state, updated_server, publish \\ true) do
    if publish do
      :ok = PubSub.publish_server_updated(updated_server)
    end

    %__MODULE__{state | server: updated_server}
  end

  defp add_actions(state, []), do: state

  defp add_actions(state, [action | remaining_actions]),
    do: state |> add_action(action) |> add_actions(remaining_actions)

  defp add_action(state, action), do: %__MODULE__{state | actions: [action | state.actions]}

  defp cancel_timer_action(timer_ref), do: {:cancel_timer, timer_ref}

  defp connect_action(%__MODULE__{server: server, username: username}) do
    host = server.ip_address.address
    port = server.ssh_port || 22

    pid = self()
    ssh_host_key_fingerprints = Server.valid_ssh_host_key_fingerprints(server)

    {:connect,
     fn task_state, task_factory ->
       task =
         task_factory.(host, port, username,
           silently_accept_hosts:
             {:sha256,
              fn _peer_name, fingerprint_charlist ->
                fingerprint = to_string(fingerprint_charlist)

                match =
                  Enum.any?(ssh_host_key_fingerprints, &SSHKeyFingerprint.match?(&1, fingerprint))

                if not match do
                  Logger.warning(
                    "Refusing to connect to server #{server.id} because its SSH host key fingerprint #{inspect(fingerprint)} does not match any of the expected fingerprints"
                  )

                  send(pid, {:unknown_key_fingerprint, fingerprint})
                end

                match
              end}
         )

       %__MODULE__{task_state | tasks: Map.put(task_state.tasks, :connect, task.ref)}
     end}
  end

  defp notify_server_offline_action, do: :notify_server_offline

  defp track(state),
    do: %__MODULE__{
      state
      | actions:
          state.actions ++
            [{:track, "servers", state.server.id, to_real_time_state(state)}]
    }

  defp update_tracking_action,
    do:
      {:update_tracking, "servers",
       fn state ->
         new_state = %__MODULE__{state | version: state.version + 1}
         real_time_state = to_real_time_state(new_state)
         {real_time_state, new_state}
       end}

  defp monitor_action(pid), do: {:monitor, pid}
  defp demonitor_action(ref), do: {:demonitor, ref}

  defp schedule_connection_action,
    do: send_message_action(:connect, 2000 + :rand.uniform(5000), :connection_timer)

  defp run_playbook_action(playbook_run, cause), do: {:run_playbook, playbook_run, cause}

  defp measure_load_average_action,
    do: send_message_action(:measure_load_average, 20_000, :load_average_timer)

  defp retry_action(%{in_seconds: in_seconds}),
    do: send_message_action(:retry_connecting, in_seconds * 1000, :retry_timer)

  defp send_message_action(msg, ms, timer_key),
    do:
      {:send_message,
       fn timer_state, timer_factory ->
         timer = timer_factory.(msg, ms)
         Map.put(timer_state, timer_key, timer)
       end}

  defp update_user_to_connect_as(
         %__MODULE__{server: %Server{set_up_at: nil, username: username}} = state
       ),
       do: %__MODULE__{state | username: username}

  defp update_user_to_connect_as(
         %__MODULE__{server: %Server{set_up_at: %DateTime{}, app_username: app_username}} = state
       ),
       do: %__MODULE__{state | username: app_username}

  defp connect_with_app_username(
         %__MODULE__{server: %Server{set_up_at: %DateTime{}, app_username: app_username}} = state
       ),
       do: %__MODULE__{state | username: app_username}

  defp user_to_connect_as(%Server{set_up_at: nil, username: username}), do: username
  defp user_to_connect_as(%Server{app_username: app_username}), do: app_username

  defp with_reply(state, reply), do: {state, reply}

  defp api_base_url,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:api_base_url)

  defp execute_telemetry_event(key, measurements) when is_atom(key) and is_map(measurements),
    do: execute_telemetry_event([key], measurements)

  defp execute_telemetry_event(keys, measurements) when is_list(keys) and is_map(measurements),
    do:
      :telemetry.execute(
        keys |> Enum.reduce(@event_base, fn key, acc -> [key | acc] end) |> Enum.reverse(),
        measurements,
        %{}
      )

  defp persist_server_event!(event, server, now, causation_event \\ nil),
    do:
      event
      |> new_event(%{}, caused_by: causation_event, occurred_at: now)
      |> add_to_stream(server)
      |> initiated_by(server)
      |> Repo.insert!()
end
