defmodule ArchiDep.Servers.ServerManagerState do
  require Logger
  require Record
  import ArchiDep.Helpers.SchemaHelpers, only: [trim_to_nil: 1]
  alias ArchiDep.Helpers.NetHelpers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerConnection
  alias ArchiDep.Students.Schemas.Class
  alias Ecto.UUID

  Record.defrecord(:connecting_state,
    connection_ref: nil,
    connection_pid: nil,
    retrying: false
  )

  Record.defrecord(:checking_access_state,
    connection_ref: nil,
    connection_pid: nil
  )

  Record.defrecord(:connected_state, connection_ref: nil, connection_pid: nil)

  Record.defrecord(:reconnecting_state,
    connection_ref: nil,
    connection_pid: nil,
    retrying: false
  )

  @enforce_keys [
    :connection_state,
    :server,
    :pipeline,
    :username,
    :storage,
    :actions
  ]
  defstruct [
    :connection_state,
    :server,
    :pipeline,
    :username,
    :storage,
    actions: [],
    tasks: %{},
    ansible_playbooks: [],
    problems: [],
    retry_timer: nil
  ]

  @type t :: %__MODULE__{
          connection_state:
            :not_connected
            | connecting_state()
            | connected_state()
            | reconnecting_state()
            | :disconnected,
          server: Server.t(),
          pipeline: Pipeline.t(),
          username: String.t(),
          storage: :ets.tid(),
          actions: list(action()),
          tasks: %{atom() => reference()},
          ansible_playbooks: list(AnsiblePlaybookRun.t()),
          problems: list(problem()),
          retry_timer: reference() | nil
        }

  @type network_port :: NetHelpers.network_port()

  @type connecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            retrying: false | {pos_integer(), DateTime.t(), pos_integer(), term}
          )

  @type checking_access_state ::
          record(:checking_access_state, connection_ref: reference(), connection_pid: pid())

  @type connected_state ::
          record(:connected_state, connection_ref: reference(), connection_pid: pid())

  @type reconnecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid(),
            retrying: false | {pos_integer(), DateTime.t(), pos_integer(), term}
          )

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
  @type retry_action :: {:retry, (t(), (pos_integer() -> reference()) -> t())}
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook, AnsiblePlaybookRun.t()}
  @type track_action :: {:track, String.t(), UUID.t(), map()}
  @type action ::
          connect_action()
          | demonitor_action()
          | notify_server_offline()
          | retry_action()
          | run_command_action()
          | run_playbook_action()
          | track_action()

  @type expected_property_mismatch_problem ::
          {:expected_property_mismatch, atom(), term(), term()}
  @type gather_facts_failed_problem :: {:gather_facts_failed, term()}
  @type missing_sudo_access_problem :: {:missing_sudo_access, String.t(), String.t()}
  @type sudo_access_check_failed_problem :: {:sudo_access_check_failed, term()}
  @type problem ::
          expected_property_mismatch_problem()
          | gather_facts_failed_problem()
          | missing_sudo_access_problem()
          | sudo_access_check_failed_problem()

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

  @spec init(UUID.t(), Pipeline.t()) :: t()
  def init(server_id, pipeline) do
    Logger.debug("Init server manager for server #{server_id}")

    {:ok, server} = Server.fetch_server(server_id)
    storage = :ets.new(:server_manager, [:set, :private])

    app_user_created =
      AnsiblePlaybookRun.successful_playbook_run?(server, Ansible.app_user_playbook())

    username =
      if app_user_created do
        server.app_username
      else
        server.username
      end

    %__MODULE__{
      connection_state: :not_connected,
      server: server,
      pipeline: pipeline,
      username: username,
      storage: storage,
      actions: [
        {:track, "servers", server.id, %{state: :not_connected}}
      ]
    }
  end

  @spec online?(t()) :: boolean()
  def online?(%__MODULE__{connection_state: connected_state()}), do: true
  def online?(_state), do: false

  @spec connection_idle(t(), pid()) :: t()

  def connection_idle(
        %__MODULE__{connection_state: :not_connected} = state,
        connection_pid
      ),
      do: connect(state, connection_pid, false)

  def connection_idle(
        %__MODULE__{connection_state: :disconnected} = state,
        connection_pid
      ),
      do: connect(state, connection_pid, false)

  def retry_connecting(
        %__MODULE__{
          connection_state: connecting_state(connection_pid: connection_pid, retrying: retrying)
        } = state
      )
      when retrying != false,
      do: connect(state, connection_pid, retrying)

  def retry_connecting(
        %__MODULE__{
          connection_state: reconnecting_state(connection_pid: connection_pid, retrying: retrying)
        } = state
      )
      when retrying != false,
      do: connect(state, connection_pid, retrying)

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
        actions: [
          {:connect,
           fn task_state, task_factory ->
             task = task_factory.(host, port, username, silently_accept_hosts: true)
             %__MODULE__{task_state | tasks: Map.put(task_state.tasks, :connect, task.ref)}
           end}
        ]
    }
  end

  @spec handle_task_result(t(), reference(), term()) :: t()

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

  def handle_task_result(
        %__MODULE__{
          connection_state:
            checking_access_state(connection_ref: connection_ref, connection_pid: connection_pid),
          tasks: %{check_access: check_access_ref}
        } = state,
        check_access_ref,
        result
      ) do
    server = state.server

    case result do
      {:ok, _stdout, _stderr, 0} ->
        if state.username == server.app_username do
          Logger.info(
            "Server manager has sudo access to server #{server.id} as #{state.username}; gathering facts..."
          )

          %__MODULE__{
            state
            | connection_state:
                connected_state(
                  connection_ref: connection_ref,
                  connection_pid: connection_pid
                ),
              actions: [
                get_load_average(),
                gather_facts()
              ]
          }
        else
          Logger.info(
            "Server manager has sudo access to server #{server.id} as #{state.username}; setting up app user..."
          )

          playbook = Ansible.app_user_playbook()

          playbook_run =
            Tracker.track_playbook!(playbook, server, state.username, %{
              "app_user_authorized_key" => ArchiDep.Application.public_key()
            })

          %__MODULE__{
            state
            | connection_state:
                connected_state(
                  connection_ref: connection_ref,
                  connection_pid: connection_pid
                ),
              ansible_playbooks: [playbook_run | state.ansible_playbooks],
              actions: [
                {:run_playbook, playbook_run}
              ]
          }
        end

      {:ok, _stdout, stderr, _exit_code} ->
        Logger.info(
          "Server manager does not have sudo access to server #{server.id} as #{state.username}; connected with problems"
        )

        %__MODULE__{
          state
          | connection_state:
              connected_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              get_load_average()
            ],
            problems: [
              {:missing_sudo_access, server.username, String.trim(stderr)}
            ]
        }

      {:error, reason} ->
        Logger.error(
          "Server manager could not check sudo access to server #{server.id} as #{state.username} because #{inspect(reason)}; connected with problems"
        )

        %__MODULE__{
          state
          | connection_state:
              connected_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              get_load_average()
            ],
            problems: [
              {:sudo_access_check_failed, reason}
            ]
        }
    end
    |> drop_task(:check_access, check_access_ref)
  end

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
      Logger.info("Received load average from server #{state.server.id}: #{m1}, #{m5}, #{m15}")
    end

    drop_task(state, :get_load_average, get_load_average_ref)
  end

  def handle_task_result(
        %__MODULE__{
          connection_state: connected_state(),
          tasks: %{gather_facts: gather_facts_ref},
          problems: problems
        } = state,
        gather_facts_ref,
        result
      ) do
    case result do
      {:ok, facts} ->
        :ets.insert(state.storage, {:facts, facts})

        %{
          state
          | problems: detect_server_properties_mismatches(problems, state.server, facts)
        }

      _anything_else ->
        state
    end
    |> drop_task(:gather_facts, gather_facts_ref)
  end

  defp handle_connect_task_result(
         state,
         connection_ref,
         connection_pid,
         connection_task_ref,
         result
       ) do
    server = state.server

    case result do
      :ok ->
        Logger.info(
          "Server manager is connected to server #{server.id} as #{state.username}; checking sudo access..."
        )

        %__MODULE__{
          state
          | connection_state:
              checking_access_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              check_sudo_access()
            ]
        }

      {:error, reason} ->
        Logger.info(
          "Server manager could not connect to server #{server.id} as #{state.username} because #{inspect(reason)}"
        )

        retry(state, reason)
    end
    |> drop_task(:connect, connection_task_ref)
  end

  defp retry(
         %__MODULE__{
           connection_state:
             connecting_state(
               connection_ref: connection_ref,
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
          connecting_state(
            connection_ref: connection_ref,
            connection_pid: connection_pid,
            retrying: retrying
          ),
        actions: [retry_action(retrying)]
    }
  end

  defp retry(
         %__MODULE__{
           connection_state:
             reconnecting_state(
               connection_ref: connection_ref,
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
          reconnecting_state(
            connection_ref: connection_ref,
            connection_pid: connection_pid,
            retrying: retrying
          ),
        actions: [retry_action(retrying)]
    }
  end

  defp retry(false, reason),
    do: {1, DateTime.utc_now(), List.first(@retry_intervals_seconds), reason}

  defp retry({previous_retry, _previous_time, _previous_seconds, _previous_reason}, reason) do
    next_retry = previous_retry + 1

    seconds =
      Enum.at(@retry_intervals_seconds, previous_retry) ||
        List.last(@retry_intervals_seconds)

    {next_retry, DateTime.utc_now(), seconds, reason}
  end

  defp retry_action({_retry, _from_time, seconds, _reason}),
    do:
      {:retry,
       fn retry_state, retry_factory ->
         retry = retry_factory.(seconds * 1000)
         %__MODULE__{retry_state | retry_timer: retry}
       end}

  @spec ansible_playbook_completed(t(), UUID.t()) :: t()
  def ansible_playbook_completed(
        %__MODULE__{
          connection_state:
            connected_state(connection_pid: connection_pid, connection_ref: connection_ref),
          ansible_playbooks: [
            %AnsiblePlaybookRun{id: run_id} = run | remaining_playbooks
          ]
        } = state,
        run_id
      ) do
    server = state.server
    Logger.info("Ansible playbook #{run.playbook} completed for server #{server.id}")

    {username, actions} =
      if state.username == server.username and
           run.playbook == AnsiblePlaybook.name(Ansible.app_user_playbook()) do
        host = server.ip_address.address
        port = server.ssh_port || 22
        new_username = server.app_username

        {new_username,
         [
           {:connect,
            fn task_state, task_factory ->
              task = task_factory.(host, port, new_username, silently_accept_hosts: true)

              %__MODULE__{
                task_state
                | connection_state:
                    reconnecting_state(
                      connection_pid: connection_pid,
                      connection_ref: connection_ref
                    ),
                  tasks: Map.put(task_state.tasks, :connect, task.ref)
              }
            end}
           | state.actions
         ]}
      else
        {state.username, state.actions}
      end

    %__MODULE__{
      state
      | username: username,
        actions: actions,
        ansible_playbooks: remaining_playbooks
    }
  end

  @spec class_updated(t(), Class.t()) :: t()
  def class_updated(
        %__MODULE__{
          server: %Server{id: server_id, class: %Class{id: class_id, version: version}},
          problems: problems
        } = state,
        %Class{id: class_id, version: new_version} = class
      )
      when new_version > version do
    Logger.info(
      "Server manager for server #{server_id} received class update to version #{new_version}"
    )

    facts =
      case :ets.lookup(state.storage, :facts) do
        [{:facts, facts}] -> facts
        [] -> nil
      end

    %__MODULE__{
      state
      | server: %Server{
          state.server
          | class: class
        },
        problems: detect_server_properties_mismatches(problems, state.server, facts)
    }
  end

  @spec class_updated(t(), Class.t()) :: t()
  def class_updated(state, _outdated_class) do
    state
  end

  @spec server_updated(t(), Server.t()) :: t()
  def server_updated(
        %__MODULE__{server: %Server{id: server_id, version: version}, problems: problems} = state,
        %Server{id: server_id, version: new_version} = new_server
      )
      when new_version > version do
    Logger.info(
      "Server manager for server #{server_id} received server update to version #{new_version}"
    )

    facts =
      case :ets.lookup(state.storage, :facts) do
        [{:facts, facts}] -> facts
        [] -> nil
      end

    %__MODULE__{
      state
      | server: new_server,
        problems: detect_server_properties_mismatches(problems, state.server, facts)
    }
  end

  @spec server_updated(t(), Server.t()) :: t()
  def server_updated(state, _outdated_server) do
    state
  end

  @spec connection_crashed(t(), pid(), term()) :: t()
  def connection_crashed(
        %__MODULE__{connection_state: connected_state(connection_pid: connection_pid)} = state,
        connection_pid,
        reason
      ) do
    :ets.delete(state.storage, :facts)
    server = state.server
    Logger.info("Connection to server #{server.id} crashed because: #{inspect(reason)}")
    %__MODULE__{state | connection_state: :disconnected, actions: [:notify_server_offline]}
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

  defp detect_server_properties_mismatches(problems, _server, nil),
    do: Enum.filter(problems, fn problem -> elem(problem, 0) != :expected_property_mismatch end)

  defp detect_server_properties_mismatches(problems, server, facts),
    do:
      problems
      |> Enum.filter(fn problem -> elem(problem, 0) != :expected_property_mismatch end)
      |> detect_server_property_mismatch(:cpus, server, facts, ["ansible_processor_count"])
      |> detect_server_property_mismatch(:cores, server, facts, ["ansible_processor_cores"])
      |> detect_server_property_mismatch(:vcpus, server, facts, ["ansible_processor_vcpus"])
      |> detect_server_property_mismatch(:memory, server, facts, [
        "ansible_memory_mb",
        "real",
        "total"
      ])
      |> detect_server_property_mismatch(:swap, server, facts, [
        "ansible_memory_mb",
        "swap",
        "total"
      ])
      |> detect_server_property_mismatch(:system, server, facts, ["ansible_system"])
      |> detect_server_property_mismatch(:architecture, server, facts, ["ansible_architecture"])
      |> detect_server_property_mismatch(:os_family, server, facts, ["ansible_os_family"])
      |> detect_server_property_mismatch(:distribution, server, facts, ["ansible_distribution"])
      |> detect_server_property_mismatch(:distribution_release, server, facts, [
        "ansible_distribution_release"
      ])
      |> detect_server_property_mismatch(:distribution_version, server, facts, [
        "ansible_distribution_version"
      ])

  defp detect_server_property_mismatch(
         problems,
         property,
         server,
         facts,
         path
       )
       when is_struct(server, Server),
       do:
         detect_server_property_mismatch(
           problems,
           property,
           Map.get(
             server.class,
             String.to_existing_atom("expected_server_#{Atom.to_string(property)}")
           ),
           Map.get(server, String.to_existing_atom("expected_#{Atom.to_string(property)}")),
           get_in(facts, path)
         )

  defp detect_server_property_mismatch(
         problems,
         _property,
         _expected_class_value,
         0,
         _actual_value
       ),
       do: problems

  defp detect_server_property_mismatch(
         problems,
         _property,
         "*",
         nil,
         _actual_value
       ),
       do: problems

  defp detect_server_property_mismatch(
         problems,
         _property,
         _expected_class_value,
         "*",
         _actual_value
       ),
       do: problems

  defp detect_server_property_mismatch(problems, _property, nil, nil, _actual_value), do: problems

  defp detect_server_property_mismatch(
         problems,
         property,
         expected_class_value,
         expected_server_value,
         actual_value
       )
       when (is_binary(expected_class_value) or is_nil(expected_class_value)) and
              (is_binary(expected_server_value) or is_nil(expected_server_value)) and
              (is_binary(actual_value) or is_nil(actual_value)),
       do:
         detect_server_property_mismatch(
           problems,
           property,
           {trim_to_nil(expected_server_value || expected_class_value), trim_to_nil(actual_value)}
         )

  defp detect_server_property_mismatch(
         problems,
         property,
         expected_class_value,
         expected_server_value,
         actual_value
       ),
       do:
         detect_server_property_mismatch(
           problems,
           property,
           {expected_server_value || expected_class_value, actual_value}
         )

  defp detect_server_property_mismatch(problems, _property, {nil, _actual}),
    do: problems

  defp detect_server_property_mismatch(problems, _property, {expected, expected}),
    do: problems

  defp detect_server_property_mismatch(problems, property, {expected, actual})
       when property in [:memory, :swap] and expected != 0 do
    difference = abs(expected - actual)
    ratio = difference / expected

    if ratio > 0.1 do
      detect_server_property_mismatch(problems, property, {expected, actual})
    else
      problems
    end
  end

  defp detect_server_property_mismatch(problems, property, {expected, actual}),
    do:
      problems ++
        [
          {:expected_property_mismatch, property, expected, actual}
        ]
end
