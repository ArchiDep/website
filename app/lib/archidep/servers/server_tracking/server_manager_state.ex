defmodule ArchiDep.Servers.ServerTracking.ServerManagerState do
  @moduledoc """
  The state of a server manager for a single server. It contains the server's
  connection state and various other information about the server. It is also
  responsible for determining the next actions to be performed on the server
  depending on its state.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerManagerBehaviour

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Helpers.NetHelpers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
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
    :username,
    :actions
  ]
  defstruct [
    :server,
    :pipeline,
    :username,
    :actions,
    connection_state: not_connected_state(),
    # TODO: tasks, ansible playbook and load average timer should be part of the connected state
    tasks: %{},
    ansible_playbook: nil,
    problems: [],
    # TODO: retry timer should be part of the retry connecting state
    retry_timer: nil,
    load_average_timer: nil,
    version: 0
  ]

  @type t :: %__MODULE__{
          connection_state: connection_state(),
          server: Server.t(),
          pipeline: Pipeline.t(),
          username: String.t(),
          actions: list(action()),
          tasks: %{optional(atom()) => reference()},
          ansible_playbook: {AnsiblePlaybookRun.t(), String.t() | nil} | nil,
          problems: list(server_problem()),
          retry_timer: reference() | nil,
          load_average_timer: reference() | nil,
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
          {:gather_facts, (t(), (String.t() -> Task.t()) -> t())}
  @type monitor_action :: {:monitor, pid()}
  @type notify_server_offline_action :: :notify_server_offline
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook, AnsiblePlaybookRun.t()}
  @type send_message_action ::
          {:send_message, (t(), (term(), pos_integer() -> reference()) -> t())}
  @type track_action :: {:track, String.t(), UUID.t(), ServerRealTimeState.t()}
  @type update_tracking_action :: {:update_tracking, String.t(), (t() -> {map(), t()})}
  @type action ::
          cancel_timer_action()
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

  @impl ServerManagerBehaviour
  def init(server_id, pipeline) do
    Logger.debug("Init server manager for server #{server_id}")

    {:ok, server} = Server.fetch_server(server_id)

    last_setup_run =
      AnsiblePlaybookRun.get_last_playbook_run(server, Ansible.setup_playbook())

    username = if server.set_up_at, do: server.app_username, else: server.username

    track(%__MODULE__{
      server: server,
      pipeline: pipeline,
      username: username,
      actions: [],
      problems:
        [] ++
          if(last_setup_run != nil and last_setup_run.state != :succeeded,
            do: [
              {:server_ansible_playbook_failed, last_setup_run.playbook, last_setup_run.state,
               AnsiblePlaybookRun.stats(last_setup_run)}
            ],
            else: []
          )
    })
  end

  @impl ServerManagerBehaviour
  def online?(%__MODULE__{connection_state: connected_state()}), do: true
  def online?(_state), do: false

  # TODO: try connecting after a while if the connection idle message is not received
  # TODO: do not attempt immediate reconnection if the connection crashed, wait a few seconds
  @impl ServerManagerBehaviour
  def connection_idle(
        %__MODULE__{connection_state: not_connected_state(), server: server} = state,
        connection_pid
      ) do
    if Server.active?(server, DateTime.utc_now()) do
      connect(state, connection_pid, false)
    else
      %__MODULE__{
        state
        | connection_state: not_connected_state(connection_pid: connection_pid),
          actions: [monitor(connection_pid)]
      }
    end
  end

  def connection_idle(
        %__MODULE__{connection_state: disconnected_state(), server: server} = state,
        connection_pid
      ) do
    if Server.active?(server, DateTime.utc_now()) do
      connect(state, connection_pid, false)
    else
      %__MODULE__{
        state
        | connection_state: not_connected_state(connection_pid: connection_pid),
          actions: [monitor(connection_pid), update_tracking()]
      }
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
      do: connect(state, connection_pid, if(manual, do: %{retrying | backoff: 0}, else: retrying))

  def retry_connecting(
        %__MODULE__{
          connection_state: connection_failed_state(connection_pid: connection_pid)
        } = state,
        _manual
      ),
      do: connect(state, connection_pid, false)

  def retry_connecting(state, _manual) do
    Logger.warning(
      "Ignore request to retry connecting to server #{state.server.id} in connection state #{inspect(state.connection_state)}"
    )

    state
  end

  defp connect(state, connection_pid, retrying) do
    server = state.server
    host = server.ip_address.address
    port = server.ssh_port || 22
    username = state.username

    %__MODULE__{
      state
      | connection_state:
          connecting_state(
            connection_ref: make_ref(),
            connection_pid: connection_pid,
            retrying: retrying
          ),
        actions:
          [
            monitor(connection_pid),
            {:connect,
             fn task_state, task_factory ->
               task = task_factory.(host, port, username, silently_accept_hosts: true)
               %__MODULE__{task_state | tasks: Map.put(task_state.tasks, :connect, task.ref)}
             end}
          ] ++
            if(state.retry_timer, do: [{:cancel_timer, state.retry_timer}], else: []) ++
            [update_tracking()],
        problems:
          Enum.reject(state.problems, fn problem ->
            match?({:server_authentication_failed, _username, _reason}, problem) or
              match?({:server_missing_sudo_access, _username, _stderr}, problem) or
              match?({:server_reconnection_failed, _reason}, problem) or
              match?({:server_sudo_access_check_failed, _username, _reason}, problem)
          end),
        retry_timer: nil
    }
  end

  @impl ServerManagerBehaviour
  # Handle connection result
  def handle_task_result(
        %__MODULE__{
          connection_state:
            connecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid
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
      result
    )
  end

  # Handle reconnection result
  def handle_task_result(
        %__MODULE__{
          connection_state:
            reconnecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid
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
      result
    )
  end

  # Handle access check result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          username: username,
          tasks: %{check_access: check_access_ref}
        } = state,
        check_access_ref,
        result
      ) do
    server = state.server

    new_state =
      case result do
        {:ok, _stdout, _stderr, 0} ->
          if username == server.app_username do
            Logger.info(
              "Server manager has sudo access to server #{server.id} as #{username}; gathering facts..."
            )

            %__MODULE__{
              state
              | actions: [
                  gather_facts(),
                  get_load_average(),
                  update_tracking()
                ]
            }
          else
            Logger.info(
              "Server manager has sudo access to server #{server.id} as #{username}; setting up app user..."
            )

            playbook_run = run_setup_playbook(server)

            %__MODULE__{
              state
              | ansible_playbook: {playbook_run, nil},
                actions: [
                  {:run_playbook, playbook_run},
                  update_tracking()
                ]
            }
          end

        {:ok, _stdout, stderr, _exit_code} ->
          Logger.info(
            "Server manager does not have sudo access to server #{server.id} as #{username}; connected with problems"
          )

          %__MODULE__{
            state
            | actions: [
                get_load_average(),
                update_tracking()
              ],
              problems: [
                {:server_missing_sudo_access, username, String.trim(stderr)}
              ]
          }

        {:error, reason} ->
          Logger.warning(
            "Server manager could not check sudo access to server #{server.id} as #{username} because #{inspect(reason)}; connected with problems"
          )

          %__MODULE__{
            state
            | actions: [
                get_load_average(),
                update_tracking()
              ],
              problems: [
                {:server_sudo_access_check_failed, username, reason}
              ]
          }
      end

    drop_task(new_state, :check_access, check_access_ref)
  end

  # Handle load average result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{get_load_average: get_load_average_ref}
        } = state,
        get_load_average_ref,
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

    drop_task(
      %__MODULE__{
        state
        | actions: [send_message(:measure_load_average, 20_000, :load_average_timer)]
      },
      :get_load_average,
      get_load_average_ref
    )
  end

  # Handle fact gathering result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{gather_facts: gather_facts_ref}
        } = state,
        gather_facts_ref,
        result
      ) do
    Logger.debug("Received fact gathering result from server #{state.server.id}")

    new_state =
      case result do
        {:ok, facts} ->
          handle_successful_facts_gathering(state, facts)

        {:error, reason} ->
          Logger.warning(
            "Server manager could not gather facts for server #{state.server.id} because #{inspect(reason)}"
          )

          %__MODULE__{
            state
            | actions: [
                update_tracking()
              ],
              problems: [
                {:server_fact_gathering_failed, reason}
              ]
          }
      end

    drop_task(new_state, :gather_facts, gather_facts_ref)
  end

  # Handle test ports result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          tasks: %{test_ports: test_ports_ref}
        } = state,
        test_ports_ref,
        result
      ) do
    new_state =
      case result do
        {:ok, _stdout, _stderr, 0} ->
          Logger.debug("Port testing script succeeded on server #{server.id}")

          %__MODULE__{
            state
            | actions: [
                check_open_ports(server),
                update_tracking()
              ]
          }

        {:ok, _stdout, stderr, exit_code} ->
          Logger.warning(
            "Port testing script exited with code #{exit_code} on server #{server.id}: #{inspect(stderr)}"
          )

          %__MODULE__{
            state
            | problems: [
                {:server_port_testing_script_failed, {:exit, exit_code, stderr}}
                | Enum.reject(
                    state.problems,
                    &(match?({:server_port_testing_script_failed, _details}, &1) or
                        match?({:server_open_ports_check_failed, _details}, &1))
                  )
              ],
              actions: [update_tracking()]
          }

        {:error, reason} ->
          Logger.error(
            "Port testing script failed on server #{server.id} because: #{inspect(reason)}"
          )

          %__MODULE__{
            state
            | problems: [
                {:server_port_testing_script_failed, {:error, reason}}
                | Enum.reject(
                    state.problems,
                    &(match?({:server_port_testing_script_failed, _details}, &1) or
                        match?({:server_open_ports_check_failed, _details}, &1))
                  )
              ],
              actions: [update_tracking()]
          }
      end

    drop_task(new_state, :test_ports, test_ports_ref)
  end

  # Handle check open ports result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          tasks: %{check_open_ports: check_open_ports_ref}
        } = state,
        check_open_ports_ref,
        result
      ) do
    new_state =
      case result do
        :ok ->
          updated_server = Server.mark_open_ports_checked!(server)

          %__MODULE__{
            state
            | server: updated_server,
              problems:
                Enum.reject(
                  state.problems,
                  &(match?({:server_port_testing_script_failed, _details}, &1) or
                      match?({:server_open_ports_check_failed, _details}, &1))
                ),
              actions: [update_tracking()]
          }

        {:error, port_problems} ->
          %__MODULE__{
            state
            | problems: [
                {:server_open_ports_check_failed, port_problems}
                | Enum.reject(
                    state.problems,
                    &(match?({:server_port_testing_script_failed, _details}, &1) or
                        match?({:server_open_ports_check_failed, _details}, &1))
                  )
              ],
              actions: [update_tracking()]
          }
      end

    drop_task(new_state, :check_open_ports, check_open_ports_ref)
  end

  # Handle connection result
  defp handle_connect_task_result(
         state,
         connection_ref,
         connection_pid,
         connection_task_ref,
         result
       ) do
    new_state =
      case result do
        :ok ->
          handle_successful_connection(state, connection_ref, connection_pid)

        {:error, :authentication_failed} ->
          handle_connection_authentication_failed(state, connection_pid)

        {:error, reason} ->
          handle_connection_failed(state, connection_pid, reason)
      end

    drop_task(new_state, :connect, connection_task_ref)
  end

  defp handle_successful_connection(
         %__MODULE__{server: server} = state,
         connection_ref,
         connection_pid
       ) do
    Logger.info(
      "Server manager is connected to server #{server.id} as #{state.username}; checking sudo access..."
    )

    %__MODULE__{
      state
      | connection_state:
          connected_state(
            connection_ref: connection_ref,
            connection_pid: connection_pid,
            time: DateTime.utc_now()
          ),
        actions: [
          check_sudo_access(),
          update_tracking()
        ],
        problems: drop_connection_problems(state.problems)
    }
  end

  defp handle_connection_authentication_failed(
         %__MODULE__{server: server} = state,
         connection_pid
       ) do
    Logger.warning(
      "Server manager could not connect to server #{server.id} as #{state.username} because authentication failed"
    )

    %__MODULE__{
      state
      | connection_state:
          connection_failed_state(
            connection_pid: connection_pid,
            reason: :authentication_failed
          ),
        actions: [update_tracking()],
        problems: [
          {:server_authentication_failed,
           if(state.username == state.server.app_username,
             do: :app_username,
             else: :username
           ), state.username}
        ]
    }
  end

  defp handle_connection_failed(%__MODULE__{server: server} = state, connection_pid, reason) do
    Logger.info(
      "Server manager could not connect to server #{server.id} as #{state.username} because #{inspect(reason)}"
    )

    case state.connection_state do
      reconnecting_state() ->
        %__MODULE__{
          state
          | connection_state:
              connection_failed_state(
                connection_pid: connection_pid,
                reason: reason
              ),
            actions: [update_tracking()],
            problems: [{:server_reconnection_failed, reason}]
        }

      connecting_state() ->
        server_username = state.server.username

        new_problems =
          case {reason, state.username} do
            {:timeout, ^server_username} ->
              [
                {:server_connection_timed_out, state.server.ip_address.address,
                 state.server.ssh_port || 22, server_username}
              ]

            {:econnrefused, ^server_username} ->
              [
                {:server_connection_refused, state.server.ip_address.address,
                 state.server.ssh_port || 22, server_username}
              ]

            _anything_else ->
              []
          end

        retry(
          %{
            state
            | problems: drop_connection_problems(state.problems) ++ new_problems
          },
          reason
        )
    end
  end

  defp retry(
         %__MODULE__{
           connection_state:
             connecting_state(
               connection_pid: connection_pid,
               retrying: retrying
             )
         } = state,
         reason
       ) do
    retrying = retry(retrying, reason)

    %__MODULE__{
      state
      | connection_state:
          retry_connecting_state(
            connection_pid: connection_pid,
            retrying: retrying
          ),
        actions: [retry_action(retrying), update_tracking()]
    }
  end

  defp retry(false, reason),
    do: %{
      retry: 1,
      backoff: 0,
      time: DateTime.utc_now(),
      in_seconds: List.first(@retry_intervals_seconds),
      reason: reason
    }

  defp retry(%{retry: previous_retry, backoff: previous_backoff}, reason) do
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

  defp retry_action(%{in_seconds: in_seconds}),
    do: send_message(:retry_connecting, in_seconds * 1000, :retry_timer)

  defp handle_successful_facts_gathering(state, facts) do
    updated_server = Server.update_last_known_properties!(state.server, facts)
    :ok = PubSub.publish_server_updated(updated_server)

    setup_playbook = Ansible.setup_playbook()

    last_setup_run =
      AnsiblePlaybookRun.get_last_playbook_run(updated_server, setup_playbook)

    if last_setup_run == nil do
      Logger.warning(
        "No previous Ansible setup playbook run found for server #{updated_server.id}"
      )
    end

    if last_setup_run != nil and
         (last_setup_run.state != :succeeded or
            setup_playbook.digest != last_setup_run.digest) do
      if setup_playbook.digest != last_setup_run.digest do
        Logger.notice(
          "Re-running Ansible setup playbook for server #{updated_server.id} because its digest has changed from #{Base.encode16(last_setup_run.digest, case: :lower)} to #{Base.encode16(setup_playbook.digest, case: :lower)}"
        )
      else
        Logger.notice(
          "Re-running Ansible setup playbook for server #{updated_server.id} because its last run did not succeed (#{inspect(last_setup_run.state)})"
        )
      end

      playbook_run = run_setup_playbook(updated_server)

      %__MODULE__{
        state
        | server: updated_server,
          ansible_playbook: {playbook_run, nil},
          actions: [{:run_playbook, playbook_run}, update_tracking()],
          problems: detect_server_properties_mismatches(state.problems, updated_server)
      }
    else
      maybe_test_ports(%__MODULE__{
        state
        | server: updated_server,
          actions: [update_tracking()],
          problems: detect_server_properties_mismatches(state.problems, updated_server)
      })
    end
  end

  @impl ServerManagerBehaviour
  def ansible_playbook_event(
        %__MODULE__{
          ansible_playbook: {%AnsiblePlaybookRun{id: run_id} = playbook_run, _previous_task}
        } = state,
        run_id,
        ongoing_task
      ) do
    %__MODULE__{
      state
      | ansible_playbook: {playbook_run, ongoing_task},
        actions: [
          update_tracking()
        ]
    }
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
          connection_state:
            connected_state(connection_pid: connection_pid, connection_ref: connection_ref),
          ansible_playbook: {%AnsiblePlaybookRun{id: run_id, playbook: "setup"}, _task}
        } = state,
        run_id
      ) do
    server = state.server
    Logger.info("Ansible setup playbook completed for server #{server.id}")

    run = AnsiblePlaybookRun.get_completed_run!(run_id)

    if run.state == :succeeded and state.username == server.username do
      host = server.ip_address.address
      port = server.ssh_port || 22
      new_username = server.app_username

      set_up_server = Server.mark_as_set_up!(server)

      %__MODULE__{
        state
        | connection_state:
            reconnecting_state(
              connection_pid: connection_pid,
              connection_ref: connection_ref
            ),
          server: set_up_server,
          username: new_username,
          ansible_playbook: nil,
          actions:
            [
              {:connect,
               fn task_state, task_factory ->
                 task = task_factory.(host, port, new_username, silently_accept_hosts: true)

                 %__MODULE__{
                   task_state
                   | tasks: Map.put(task_state.tasks, :connect, task.ref)
                 }
               end}
            ] ++
              if(state.load_average_timer,
                do: [{:cancel_timer, state.load_average_timer}],
                else: []
              ) ++ [update_tracking()],
          problems:
            Enum.reject(
              state.problems,
              &match?({:server_ansible_playbook_failed, "setup", _state, _stats}, &1)
            ),
          load_average_timer: nil
      }
    else
      problem =
        if run.state !== :succeeded do
          [
            {:server_ansible_playbook_failed, run.playbook, run.state,
             AnsiblePlaybookRun.stats(run)}
          ]
        else
          []
        end

      %__MODULE__{
        state
        | ansible_playbook: nil,
          actions: [update_tracking()],
          problems:
            Enum.reject(
              state.problems,
              &match?({:server_ansible_playbook_failed, "setup", _state, _stats}, &1)
            ) ++ problem
      }
    end
  end

  @impl ServerManagerBehaviour
  def retry_ansible_playbook(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          problems: problems,
          tasks: tasks,
          ansible_playbook: nil
        } = state,
        "setup"
      )
      when tasks == %{} do
    has_failed_playbook =
      Enum.any?(problems, fn
        {:server_ansible_playbook_failed, "setup", _state, _stats} -> true
        _any_other_problem -> false
      end)

    if has_failed_playbook do
      Logger.info("Retrying Ansible playbook setup for server #{server.id}")

      playbook_run = run_setup_playbook(server)

      {%__MODULE__{
         state
         | ansible_playbook: {playbook_run, nil},
           actions: [
             {:run_playbook, playbook_run},
             update_tracking()
           ]
       }, :ok}
    else
      Logger.info(
        "Ignoring retry request for Ansible playbook setup for server #{server.id} because there is no such failed run"
      )

      {state, :ok}
    end
  end

  def retry_ansible_playbook(%__MODULE__{connection_state: connected_state()} = state, playbook) do
    Logger.info(
      "Ignoring retry request for Ansible playbook #{playbook} because the server is busy"
    )

    {state, {:error, :server_busy}}
  end

  def retry_ansible_playbook(%__MODULE__{} = state, playbook) do
    Logger.info(
      "Ignoring retry request for Ansible playbook #{playbook} because the server is not connected"
    )

    {state, {:error, :server_not_connected}}
  end

  @impl ServerManagerBehaviour
  def retry_checking_open_ports(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          problems: problems,
          tasks: tasks,
          ansible_playbook: nil
        } = state
      )
      when tasks == %{} do
    Logger.info("Retrying checking open ports for server #{server.id}")

    has_failed_checking_open_ports =
      Enum.any?(
        problems,
        &(match?({:server_port_testing_script_failed, _details}, &1) or
            match?({:server_open_ports_check_failed, _details}, &1))
      )

    if has_failed_checking_open_ports do
      {%__MODULE__{
         state
         | actions: [
             test_ports(),
             update_tracking()
           ]
       }, :ok}
    else
      Logger.info(
        "Ignoring retry request for checking open ports for server #{server.id} because there is no port checking problem"
      )

      {state, :ok}
    end
  end

  def retry_checking_open_ports(
        %__MODULE__{connection_state: connected_state(), server: server} = state
      ) do
    Logger.info(
      "Ignoring retry request for checking open ports for server #{server.id} because the server is busy"
    )

    {state, {:error, :server_busy}}
  end

  def retry_checking_open_ports(%__MODULE__{server: server} = state) do
    Logger.info(
      "Ignoring retry request for checking open ports for server #{server.id} because the server is not connected"
    )

    {state, {:error, :server_not_connected}}
  end

  @impl ServerManagerBehaviour
  def group_updated(
        %__MODULE__{
          server: %Server{
            id: server_id,
            group: %ServerGroup{id: group_id, version: current_version} = current_group
          },
          problems: problems
        } = state,
        %{id: group_id, version: version} = group
      ) do
    Logger.info(
      "Server manager for server #{server_id} received group update from version #{current_version} to version #{version}"
    )

    new_group = ServerGroup.refresh!(current_group, group)

    if new_group == current_group do
      state
    else
      new_server = %Server{state.server | group: new_group}

      auto_activate_or_deactivate(%__MODULE__{
        state
        | server: new_server,
          # TODO: do not add update tracking action if there is already one
          actions: [update_tracking()],
          problems: detect_server_properties_mismatches(problems, new_server)
      })
    end
  end

  @impl ServerManagerBehaviour
  def connection_crashed(
        %__MODULE__{connection_state: connected_state(connection_pid: connection_pid)} = state,
        connection_pid,
        reason
      ),
      do: disconnect(state, reason)

  def connection_crashed(
        %__MODULE__{connection_state: disconnected_state()} = state,
        _connection_pid,
        reason
      ),
      do: disconnect(state, reason)

  defp disconnect(state, reason) do
    server = state.server
    Logger.info("Connection to server #{server.id} crashed because: #{inspect(reason)}")

    actions =
      [:notify_server_offline] ++
        if(state.retry_timer, do: [{:cancel_timer, state.retry_timer}], else: []) ++
        if(state.load_average_timer, do: [{:cancel_timer, state.load_average_timer}], else: []) ++
        Enum.map(state.tasks, fn {_task_name, task_ref} -> {:demonitor, task_ref} end) ++
        [update_tracking()]

    %__MODULE__{
      state
      | connection_state: disconnected_state(time: DateTime.utc_now()),
        actions: actions,
        problems: drop_connected_problems(state.problems),
        tasks: %{},
        retry_timer: nil,
        load_average_timer: nil
    }
  end

  @impl ServerManagerBehaviour
  def update_server(state, auth, data) do
    case state do
      %__MODULE__{connection_state: connecting_state()} ->
        {:error, :server_busy}

      %__MODULE__{connection_state: reconnecting_state()} ->
        {:error, :server_busy}

      _any_other_state ->
        do_update_server(state, auth, data)
    end
  end

  defp do_update_server(%__MODULE__{problems: problems} = state, auth, data) do
    case UpdateServer.update_server(auth, state.server, data) do
      {:ok, updated_server} ->
        new_state =
          auto_activate_or_deactivate(%__MODULE__{
            state
            | server: updated_server,
              username:
                if(updated_server.set_up_at,
                  do: updated_server.app_username,
                  else: updated_server.username
                ),
              # TODO: do not add update tracking action if there is already one
              actions: [update_tracking()],
              problems: detect_server_properties_mismatches(problems, updated_server)
          })

        {new_state, {:ok, updated_server}}

      {:error, changeset} ->
        {state, {:error, changeset}}
    end
  end

  @impl ServerManagerBehaviour
  def delete_server(
        state,
        auth
      ) do
    case state do
      %__MODULE__{connection_state: not_connected_state(), tasks: tasks, ansible_playbook: nil}
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)
        {state, :ok}

      %__MODULE__{
        connection_state: retry_connecting_state(connection_pid: connection_pid),
        tasks: tasks,
        ansible_playbook: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        {
          %__MODULE__{
            state
            | connection_state: not_connected_state(connection_pid: connection_pid),
              actions: [if(state.retry_timer, do: {:cancel_timer, state.retry_timer}, else: [])]
          },
          :ok
        }

      %__MODULE__{
        connection_state: connected_state(connection_pid: connection_pid),
        server: server,
        tasks: tasks,
        ansible_playbook: nil
      }
      when tasks == %{} ->
        :ok = ServerConnection.disconnect(server)
        :ok = DeleteServer.delete_server(auth, server)

        {
          %__MODULE__{
            state
            | connection_state: not_connected_state(connection_pid: connection_pid)
          },
          :ok
        }

      %__MODULE__{
        connection_state: connection_failed_state(connection_pid: connection_pid),
        tasks: tasks,
        ansible_playbook: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        {
          %__MODULE__{
            state
            | connection_state: not_connected_state(connection_pid: connection_pid)
          },
          :ok
        }

      %__MODULE__{
        connection_state: disconnected_state(),
        tasks: tasks,
        ansible_playbook: nil
      }
      when tasks == %{} ->
        :ok = DeleteServer.delete_server(auth, state.server)

        {
          %__MODULE__{
            state
            | connection_state: not_connected_state()
          },
          :ok
        }

      _any_other_state ->
        {state, {:error, :server_busy}}
    end
  end

  defp auto_activate_or_deactivate(
         %__MODULE__{connection_state: connection_state, server: server} = state
       ) do
    if Server.active?(server, DateTime.utc_now()) do
      case connection_state do
        not_connected_state(connection_pid: connection_pid) when connection_pid != nil ->
          connect(state, connection_pid, false)

        _any_other_state ->
          state
      end
    else
      deactivate(state)
    end
  end

  defp deactivate(
         %__MODULE__{
           connection_state: connected_state(connection_pid: connection_pid),
           server: server
         } = state
       ) do
    ServerConnection.disconnect(server.id)

    %__MODULE__{
      state
      | connection_state: not_connected_state(connection_pid: connection_pid)
    }
  end

  defp deactivate(
         %__MODULE__{connection_state: retry_connecting_state(connection_pid: connection_pid)} =
           state
       ) do
    %__MODULE__{
      state
      | connection_state: not_connected_state(connection_pid: connection_pid),
        actions:
          state.actions ++
            if(state.retry_timer,
              do: [{:cancel_timer, state.retry_timer}],
              else: []
            )
    }
  end

  defp deactivate(%__MODULE__{connection_state: disconnected_state()} = state) do
    %__MODULE__{state | connection_state: not_connected_state()}
  end

  defp deactivate(
         %__MODULE__{connection_state: connection_failed_state(connection_pid: connection_pid)} =
           state
       ) do
    %__MODULE__{
      state
      | connection_state: not_connected_state(connection_pid: connection_pid)
    }
  end

  defp deactivate(%__MODULE__{} = state) do
    state
  end

  @impl ServerManagerBehaviour
  def on_message(%__MODULE__{connection_state: connected_state()} = state, :measure_load_average),
    do: %__MODULE__{
      state
      | actions: [
          get_load_average(),
          update_tracking()
        ]
    }

  def on_message(state, :measure_load_average) do
    Logger.warning(
      "Ignoring message :measure_load_average sent to server manager for server #{state.server.id} because the server is no longer connected"
    )

    state
  end

  def on_message(state, :retry_connecting), do: retry_connecting(state, false)

  defp drop_task(%__MODULE__{actions: actions, tasks: tasks} = state, key, ref) do
    case Map.get(tasks, key) do
      nil ->
        state

      ^ref ->
        %__MODULE__{state | tasks: Map.delete(tasks, key), actions: [{:demonitor, ref} | actions]}
    end
  end

  defp maybe_test_ports(
         %__MODULE__{server: %Server{open_ports_checked_at: nil}, actions: actions} = state
       ),
       do: %__MODULE__{state | actions: [test_ports() | actions]}

  defp maybe_test_ports(%__MODULE__{} = state), do: state

  defp gather_facts,
    do:
      {:gather_facts,
       fn task_state, task_factory ->
         task = task_factory.(task_state.username)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, :gather_facts, task.ref)
         }
       end}

  defp check_open_ports(server),
    do:
      {:check_open_ports,
       fn task_state, task_factory ->
         task = task_factory.(server.ip_address.address, @ports_to_check)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, :check_open_ports, task.ref)
         }
       end}

  defp get_load_average, do: run_command(:get_load_average, "cat /proc/loadavg", 10_000)
  defp check_sudo_access, do: run_command(:check_access, "sudo -n ls", 10_000)

  defp test_ports,
    do:
      run_command(
        :test_ports,
        "sudo /usr/local/sbin/test-ports #{Enum.join(@ports_to_check, " ")}",
        10_000
      )

  defp run_command(name, command, timeout),
    do:
      {:run_command,
       fn task_state, task_factory ->
         task = task_factory.(command, timeout)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, name, task.ref)
         }
       end}

  defp detect_server_properties_mismatches(problems, %Server{last_known_properties: nil}) do
    Enum.filter(problems, fn problem ->
      elem(problem, 0) != :server_expected_property_mismatch
    end)
  end

  defp detect_server_properties_mismatches(problems, %Server{
         group: %ServerGroup{expected_server_properties: expected_server_properties},
         expected_properties: expected_properties_overrides,
         last_known_properties: last_known_properties
       })
       when last_known_properties != nil do
    expected_properties =
      ServerProperties.merge(expected_server_properties, expected_properties_overrides)

    mismatches = ServerProperties.detect_mismatches(expected_properties, last_known_properties)

    problems
    |> Enum.filter(fn problem ->
      elem(problem, 0) != :server_expected_property_mismatch
    end)
    |> Enum.concat(
      Enum.map(mismatches, fn {property, expected, actual} ->
        {:server_expected_property_mismatch, property, expected, actual}
      end)
    )
  end

  defp drop_connection_problems(problems),
    do:
      Enum.reject(
        problems,
        fn problem ->
          match?(
            {:server_connection_timed_out, _host, _port, _username},
            problem
          ) or
            match?(
              {:server_connection_refused, _host, _port, _username},
              problem
            )
        end
      )

  defp drop_connected_problems(problems),
    do:
      Enum.reject(problems, fn problem ->
        match?({:server_port_testing_script_failed, _reason}, problem) or
          match?({:server_open_ports_check_failed, _port_problems}, problem) or
          match?({:server_fact_gathering_failed, _reason}, problem)
      end)

  defp track(state),
    do: %__MODULE__{
      state
      | actions:
          state.actions ++
            [{:track, "servers", state.server.id, to_real_time_state(state)}]
    }

  defp update_tracking,
    do:
      {:update_tracking, "servers",
       fn state ->
         new_state = %__MODULE__{state | version: state.version + 1}
         real_time_state = to_real_time_state(new_state)
         {real_time_state, new_state}
       end}

  defp monitor(pid), do: {:monitor, pid}

  defp send_message(msg, ms, timer_key),
    do:
      {:send_message,
       fn timer_state, timer_factory ->
         timer = timer_factory.(msg, ms)
         Map.put(timer_state, timer_key, timer)
       end}

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

      %{connection_state: connected_state(), tasks: %{gather_facts: _ref}} ->
        :gathering_facts

      %{connection_state: connected_state(), tasks: %{test_ports: _ref}} ->
        :checking_open_ports

      %{connection_state: connected_state(), tasks: %{check_open_ports: _ref}} ->
        :checking_open_ports

      %{
        connection_state: connected_state(),
        ansible_playbook: {%AnsiblePlaybookRun{id: id, playbook: playbook}, task}
      } ->
        {:running_playbook, playbook, id, task}

      _anything_else ->
        nil
    end
  end

  defp run_setup_playbook(server) do
    playbook = Ansible.setup_playbook()

    username = if server.set_up_at, do: server.app_username, else: server.username
    token = Token.sign(server.secret_key, "server auth", server.id)

    Tracker.track_playbook!(playbook, server, username, %{
      "api_base_url" => api_base_url(),
      "app_user_name" => server.app_username,
      "app_user_authorized_key" => ssh_public_key(),
      "server_id" => server.id,
      "server_token" => token
    })
  end

  defp api_base_url,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:api_base_url)

  defp ssh_public_key,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:ssh_public_key)
end
