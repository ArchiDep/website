defmodule ArchiDep.Servers.ServerManagerState do
  require Logger
  require Record
  import ArchiDep.Servers.ServerConnectionState
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Authentication
  alias ArchiDep.Helpers.NetHelpers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.DeleteServer
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerConnection
  alias ArchiDep.Servers.ServerConnectionState
  alias ArchiDep.Servers.Types
  alias ArchiDep.Servers.UpdateServer
  alias Ecto.Changeset
  alias Ecto.UUID
  alias Phoenix.Token

  @enforce_keys [
    :server,
    :pipeline,
    :username,
    :storage,
    :actions
  ]
  defstruct [
    :server,
    :pipeline,
    :username,
    :storage,
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
          storage: :ets.tid(),
          actions: list(action()),
          tasks: %{atom() => reference()},
          ansible_playbook: {AnsiblePlaybookRun.t(), String.t() | nil} | nil,
          problems: list(server_problem()),
          retry_timer: reference() | nil,
          load_average_timer: reference() | nil,
          version: non_neg_integer()
        }

  @type network_port :: NetHelpers.network_port()

  @type connection_state :: ServerConnectionState.connection_state()

  @type cancel_timer_action :: {:cancel_timer, reference()}
  @type connect_action ::
          {:connect,
           (t(),
            (:inet.ip_address(), network_port(), String.t(), ServerConnection.connect_options() ->
               Task.t()) ->
              t())}
  @type demonitor_action :: {:demonitor, reference()}
  @type gather_facts_action ::
          {:gather_facts, (t(), (String.t() -> Task.t()) -> t())}
  @type notify_server_offline :: :notify_server_offline
  @type retry_connecting_action ::
          {:retry_connecting, (t(), (pos_integer() -> reference()) -> t())}
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook, AnsiblePlaybookRun.t()}
  @type schedule_load_average_measurement_action ::
          {:schedule_load_average_measurement, (t(), (pos_integer() -> reference()) -> t())}
  @type track_action :: {:track, String.t(), UUID.t(), map()}
  @type update_tracking_action :: {:update_tracking, String.t(), (t() -> {map(), t()})}
  @type action ::
          cancel_timer_action()
          | connect_action()
          | demonitor_action()
          | gather_facts_action()
          | notify_server_offline()
          | retry_connecting_action()
          | run_command_action()
          | run_playbook_action()
          | schedule_load_average_measurement_action()
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

  @spec init(UUID.t(), Pipeline.t()) :: t()
  def init(server_id, pipeline) do
    Logger.debug("Init server manager for server #{server_id}")

    {:ok, server} = Server.fetch_server(server_id)
    storage = :ets.new(:server_manager, [:set, :private])

    last_setup_run =
      AnsiblePlaybookRun.get_last_playbook_run(server, Ansible.setup_playbook())

    username = if server.set_up_at, do: server.app_username, else: server.username

    track(%__MODULE__{
      server: server,
      pipeline: pipeline,
      username: username,
      storage: storage,
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

  @spec online?(t()) :: boolean()
  def online?(%__MODULE__{connection_state: connected_state()}), do: true
  def online?(_state), do: false

  # FIXME: try connecting after a while if the connection idle message is not received
  # FIXME: do not attempt immediate reconnection if the connection crashed, wait a few seconds
  @spec connection_idle(t(), pid()) :: t()

  def connection_idle(
        %__MODULE__{connection_state: not_connected_state(), server: server} = state,
        connection_pid
      ) do
    if Server.active?(server, DateTime.utc_now()) do
      connect(state, connection_pid, false)
    else
      %__MODULE__{state | connection_state: not_connected_state(connection_pid: connection_pid)}
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
          actions: [update_tracking()]
      }
    end
  end

  @spec retry_connecting(t(), boolean()) :: t()

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

  def retry_connecting(state, _manual), do: state

  def retry_connecting(state) do
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
    app_username = server.app_username

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
              match?(
                {:server_connection_timed_out, _host, _port, _user_type, ^app_username},
                problem
              ) or
              match?({:server_missing_sudo_access, _username, _stderr}, problem) or
              match?({:server_reconnection_failed, _reason}, problem) or
              match?({:server_sudo_access_check_failed, _reason}, problem)
          end),
        retry_timer: nil
    }
  end

  @spec handle_task_result(t(), reference(), term()) :: t()

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
          tasks: %{check_access: check_access_ref}
        } = state,
        check_access_ref,
        result
      ) do
    server = state.server

    new_state =
      case result do
        {:ok, _stdout, _stderr, 0} ->
          if state.username == server.app_username do
            Logger.info(
              "Server manager has sudo access to server #{server.id} as #{state.username}; gathering facts..."
            )

            %__MODULE__{
              state
              | actions: [
                  get_load_average(),
                  gather_facts()
                ]
            }
          else
            Logger.info(
              "Server manager has sudo access to server #{server.id} as #{state.username}; setting up app user..."
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
            "Server manager does not have sudo access to server #{server.id} as #{state.username}; connected with problems"
          )

          %__MODULE__{
            state
            | actions: [
                get_load_average(),
                update_tracking()
              ],
              problems: [
                {:server_missing_sudo_access, server.username, String.trim(stderr)}
              ]
          }

        {:error, reason} ->
          Logger.error(
            "Server manager could not check sudo access to server #{server.id} as #{state.username} because #{inspect(reason)}; connected with problems"
          )

          %__MODULE__{
            state
            | actions: [
                get_load_average(),
                update_tracking()
              ],
              problems: [
                {:server_sudo_access_check_failed, reason}
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
        | actions: [
            {:schedule_load_average_measurement,
             fn schedule_state, schedule_factory ->
               timer = schedule_factory.(20_000)
               %__MODULE__{schedule_state | load_average_timer: timer}
             end}
          ]
      },
      :get_load_average,
      get_load_average_ref
    )
  end

  # Handle fact gathering result
  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{gather_facts: gather_facts_ref},
          problems: problems
        } = state,
        gather_facts_ref,
        result
      ) do
    new_state =
      case result do
        {:ok, facts} ->
          updated_server = Server.update_last_known_properties!(state.server, facts)
          :ok = PubSub.publish_server(updated_server)

          setup_playbook = Ansible.setup_playbook()

          last_setup_run =
            AnsiblePlaybookRun.get_last_playbook_run(updated_server, setup_playbook)

          if setup_playbook.digest != last_setup_run.digest do
            Logger.notice(
              "Re-running Ansible setup playbook for server #{updated_server.id} because its digest has changed from #{Base.encode16(last_setup_run.digest, case: :lower)} to #{Base.encode16(setup_playbook.digest, case: :lower)}"
            )

            playbook_run = run_setup_playbook(updated_server)

            %__MODULE__{
              state
              | server: updated_server,
                ansible_playbook: {playbook_run, nil},
                actions: [{:run_playbook, playbook_run}, update_tracking()],
                problems: detect_server_properties_mismatches(problems, updated_server)
            }
          else
            %__MODULE__{
              state
              | server: updated_server,
                actions: [update_tracking()],
                problems: detect_server_properties_mismatches(problems, updated_server)
            }
          end

        {:error, reason} ->
          %__MODULE__{
            state
            | actions: [update_tracking()],
              problems: [
                {:server_fact_gathering_failed, reason}
              ]
          }
      end

    drop_task(new_state, :gather_facts, gather_facts_ref)
  end

  # Handle connection result
  defp handle_connect_task_result(
         state,
         connection_ref,
         connection_pid,
         connection_task_ref,
         result
       ) do
    server = state.server

    new_state =
      case result do
        :ok ->
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
              ]
          }

        {:error, :authentication_failed} ->
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

        {:error, reason} ->
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
              retry(
                %{
                  state
                  | problems:
                      Enum.reject(
                        state.problems,
                        &match?(
                          {:server_connection_timed_out, _host, _port, _user_type, _username},
                          &1
                        )
                      ) ++
                        if(reason == :timeout and state.username == state.server.username,
                          do: [
                            {:server_connection_timed_out, state.server.ip_address.address,
                             state.server.ssh_port || 22,
                             if(state.username == state.server.app_username,
                               do: :app_username,
                               else: :username
                             ), state.username}
                          ],
                          else: []
                        )
                },
                reason
              )
          end
      end

    drop_task(new_state, :connect, connection_task_ref)
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
      backoff: 1,
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
    do:
      {:retry_connecting,
       fn retry_state, retry_factory ->
         retry = retry_factory.(in_seconds * 1000)
         %__MODULE__{retry_state | retry_timer: retry}
       end}

  @spec measure_load_average(t()) :: t()
  def measure_load_average(%__MODULE__{connection_state: connected_state()} = state),
    do: %__MODULE__{
      state
      | actions: [
          get_load_average(),
          update_tracking()
        ]
    }

  @spec ansible_playbook_event(t(), UUID.t(), String.t() | nil) :: t()
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

  @spec ansible_playbook_event(t(), UUID.t(), String.t() | nil) :: t()
  def ansible_playbook_event(state, _run_id, _ongoing_task) do
    Logger.warning(
      "Ignoring Ansible playbook event for server #{state.server.id} because no playbook is running"
    )

    state
  end

  @spec ansible_playbook_completed(t(), UUID.t()) :: t()
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

  @spec retry_ansible_playbook(t(), String.t()) :: t()
  def retry_ansible_playbook(
        %__MODULE__{
          connection_state: connected_state(),
          server: server,
          problems: problems,
          tasks: %{},
          ansible_playbook: nil
        } = state,
        "setup"
      ) do
    has_failed_playbook =
      Enum.any?(problems, fn
        {:server_ansible_playbook_failed, "setup", _state, _stats} -> true
        _ -> false
      end)

    if has_failed_playbook do
      Logger.info("Retrying Ansible playbook setup for server #{server.id}")

      playbook_run = run_setup_playbook(server)

      %__MODULE__{
        state
        | ansible_playbook: {playbook_run, nil},
          actions: [
            {:run_playbook, playbook_run},
            update_tracking()
          ]
      }
    else
      Logger.info(
        "Ignoring retry request for Ansible playbook setup for server #{server.id} because there is no such failed run"
      )

      state
    end
  end

  @spec retry_ansible_playbook(t(), String.t()) :: t()
  def retry_ansible_playbook(%__MODULE__{connection_state: connected_state()} = state, playbook) do
    Logger.info(
      "Ignoring retry request for Ansible playbook #{playbook} because the server is busy"
    )

    state
  end

  @spec retry_ansible_playbook(t(), String.t()) :: t()
  def retry_ansible_playbook(%__MODULE__{} = state, playbook) do
    Logger.info(
      "Ignoring retry request for Ansible playbook #{playbook} because the server is not connected"
    )

    state
  end

  @spec group_updated(t(), map) :: t()
  def group_updated(
        %__MODULE__{
          server: %Server{
            id: server_id,
            group: %ServerGroup{id: group_id, version: current_version} = current_group
          },
          problems: problems
        } = state,
        %{id: group_id, version: version} = group
      )
      when version > current_version do
    Logger.info(
      "Server manager for server #{server_id} received group update to version #{version}"
    )

    new_server = %Server{
      state.server
      | group: ServerGroup.refresh(current_group, group)
    }

    auto_activate_or_deactivate(%__MODULE__{
      state
      | server: new_server,
        # TODO: do not add update tracking action if there is already one
        actions: [update_tracking()],
        problems: detect_server_properties_mismatches(problems, new_server)
    })
  end

  @spec group_updated(t(), map) :: t()
  def group_updated(
        %__MODULE__{
          server: %Server{group: %ServerGroup{id: group_id}}
        } = state,
        %{id: group_id}
      ) do
    state
  end

  @spec connection_crashed(t(), pid(), term()) :: t()
  def connection_crashed(
        %__MODULE__{connection_state: connected_state(connection_pid: connection_pid)} = state,
        connection_pid,
        reason
      ) do
    server = state.server
    Logger.info("Connection to server #{server.id} crashed because: #{inspect(reason)}")

    actions =
      [:notify_server_offline] ++
        if(state.retry_timer, do: [{:cancel_timer, state.retry_timer}], else: []) ++
        if(state.load_average_timer, do: [{:cancel_timer, state.load_average_timer}], else: []) ++
        [update_tracking()]

    %__MODULE__{
      state
      | connection_state: disconnected_state(time: DateTime.utc_now()),
        actions: actions,
        retry_timer: nil,
        load_average_timer: nil
    }
  end

  @spec update_server(t(), Authentication.t(), Types.update_server_data()) ::
          {t(), {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_busy}}
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
              # TODO: do not add update tracking action if there is already one
              actions: [update_tracking()],
              problems: detect_server_properties_mismatches(problems, updated_server)
          })

        {new_state, {:ok, updated_server}}

      {:error, changeset} ->
        {state, {:error, changeset}}
    end
  end

  @spec delete_server(t(), Authentication.t()) :: {t(), :ok | {:error, :server_busy}}
  def delete_server(
        state,
        auth
      ) do
    case state do
      %__MODULE__{connection_state: not_connected_state(), tasks: %{}, ansible_playbook: nil} ->
        :ok = DeleteServer.delete_server(auth, state.server)
        {state, :ok}

      %__MODULE__{
        connection_state: retry_connecting_state(connection_pid: connection_pid),
        tasks: %{},
        ansible_playbook: nil
      } ->
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
        tasks: %{},
        ansible_playbook: nil
      } ->
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
        tasks: %{},
        ansible_playbook: nil
      } ->
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
        tasks: %{},
        ansible_playbook: nil
      } ->
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
      case connection_state do
        connected_state(connection_pid: connection_pid) ->
          ServerConnection.disconnect(server.id)

          %__MODULE__{
            state
            | connection_state: not_connected_state(connection_pid: connection_pid)
          }

        connecting_state() ->
          state

        reconnecting_state() ->
          state

        retry_connecting_state(connection_pid: connection_pid) ->
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

        disconnected_state() ->
          %__MODULE__{state | connection_state: not_connected_state()}

        connection_failed_state(connection_pid: connection_pid) ->
          %__MODULE__{
            state
            | connection_state: not_connected_state(connection_pid: connection_pid)
          }

        not_connected_state() ->
          state
      end
    end
  end

  defp drop_task(%__MODULE__{actions: actions, tasks: tasks} = state, key, ref) do
    case Map.get(tasks, key) do
      nil ->
        state

      ^ref ->
        %__MODULE__{state | tasks: Map.delete(tasks, key), actions: [{:demonitor, ref} | actions]}
    end
  end

  defp gather_facts(),
    do:
      {:gather_facts,
       fn task_state, task_factory ->
         task = task_factory.(task_state.username)

         %__MODULE__{
           task_state
           | tasks: Map.put(task_state.tasks, :gather_facts, task.ref)
         }
       end}

  defp get_load_average(), do: run_command(:get_load_average, "cat /proc/loadavg", 10_000)
  defp check_sudo_access(), do: run_command(:check_access, "sudo ls", 10_000)

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
    problems
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

  defp track(state),
    do: %__MODULE__{
      state
      | actions:
          state.actions ++
            [{:track, "servers", state.server.id, %{state: to_real_time_state(state)}}]
    }

  defp update_tracking(),
    do:
      {:update_tracking, "servers",
       fn state ->
         new_state = %__MODULE__{state | version: state.version + 1}
         real_time_state = to_real_time_state(new_state)
         {real_time_state, new_state}
       end}

  defp to_real_time_state(%__MODULE__{} = state) do
    server = state.server

    current_job =
      case state do
        %{connection_state: connecting_state()} ->
          :connecting

        %{connection_state: reconnecting_state()} ->
          :reconnecting

        %{connection_state: connected_state(), tasks: %{check_access: _ref}} ->
          :checking_access

        %{connection_state: connected_state(), tasks: %{gather_facts: _ref}} ->
          :gathering_facts

        %{
          connection_state: connected_state(),
          ansible_playbook: {%AnsiblePlaybookRun{id: id, playbook: playbook}, task}
        } ->
          {:running_playbook, playbook, id, task}

        _anything_else ->
          nil
      end

    %ServerRealTimeState{
      connection_state: state.connection_state,
      name: server.name,
      conn_params: {server.ip_address.address, server.ssh_port || 22, state.username},
      username: server.username,
      app_username: server.app_username,
      current_job: current_job,
      set_up_at: server.set_up_at,
      problems: state.problems,
      version: state.version
    }
  end

  defp run_setup_playbook(server) do
    playbook = Ansible.setup_playbook()

    username = if server.set_up_at, do: server.app_username, else: server.username
    token = Token.sign(server.secret_key, "server auth", server.id)

    Tracker.track_playbook!(playbook, server, username, %{
      "app_user_name" => server.app_username,
      "app_user_authorized_key" => ArchiDep.Application.public_key(),
      "server_id" => server.id,
      "server_token" => token
    })
  end
end
