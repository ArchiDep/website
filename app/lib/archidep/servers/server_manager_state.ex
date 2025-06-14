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
    connection_pid: nil
  )

  Record.defrecord(:connection_failed_state, reason: "could not connect")

  Record.defrecord(:checking_access_state,
    connection_ref: nil,
    connection_pid: nil
  )

  Record.defrecord(:connected_state, connection_ref: nil, connection_pid: nil)

  Record.defrecord(:reconnecting_state,
    connection_ref: nil,
    connection_pid: nil
  )

  @enforce_keys [
    :state,
    :server,
    :pipeline,
    :username,
    :storage,
    :actions,
    :tasks,
    :ansible_playbooks,
    :problems
  ]
  defstruct [
    :state,
    :server,
    :pipeline,
    :username,
    :storage,
    actions: [],
    tasks: %{},
    ansible_playbooks: [],
    problems: []
  ]

  @type t :: %__MODULE__{
          state:
            :not_connected
            | connecting_state()
            | connection_failed_state()
            | connected_state()
            | :disconnected,
          server: Server.t(),
          pipeline: Pipeline.t(),
          username: String.t(),
          storage: :ets.tid(),
          actions: list(action()),
          tasks: %{atom() => reference()},
          ansible_playbooks: list({AnsiblePlaybookRun.t(), reference()}),
          problems: list(problem()),
          storage: :ets.tid()
        }

  @type network_port :: NetHelpers.network_port()

  @type connecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid()
          )

  @type connection_failed_state :: record(:connection_failed_state, reason: term())

  @type checking_access_state ::
          record(:checking_access_state, connection_ref: reference(), connection_pid: pid())

  @type connected_state ::
          record(:connected_state, connection_ref: reference(), connection_pid: pid())

  @type reconnecting_state ::
          record(:connecting_state,
            connection_ref: reference(),
            connection_pid: pid()
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
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook, AnsiblePlaybookRun.t(), reference()}
  @type track_action :: {:track, String.t(), UUID.t(), map()}
  @type action ::
          connect_action()
          | demonitor_action()
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
      state: :not_connected,
      server: server,
      pipeline: pipeline,
      username: username,
      storage: storage,
      actions: [
        {:track, "servers", server.id, %{state: :not_connected}}
      ],
      tasks: %{},
      ansible_playbooks: [],
      problems: []
    }
  end

  @spec connection_idle(t(), pid()) :: t()

  def connection_idle(
        %__MODULE__{state: :not_connected} = state,
        connection_pid
      ),
      do: connect(state, connection_pid)

  def connection_idle(
        %__MODULE__{state: connection_failed_state()} = state,
        connection_pid
      ),
      do: connect(state, connection_pid)

  def connection_idle(
        %__MODULE__{state: :disconnected} = state,
        connection_pid
      ),
      do: connect(state, connection_pid)

  defp connect(state, connection_pid) do
    server = state.server
    host = server.ip_address.address
    port = server.ssh_port || 22
    username = state.username

    %__MODULE__{
      state
      | state:
          connecting_state(
            connection_ref: make_ref(),
            connection_pid: connection_pid
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
          state:
            connecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid
            ),
          tasks: %{connect: connection_task_ref}
        } = state,
        connection_task_ref,
        result
      ) do
    handle_connect_task_result(state, connection_ref, connection_pid, connection_task_ref, result)
  end

  def handle_task_result(
        %__MODULE__{
          state:
            reconnecting_state(
              connection_ref: connection_ref,
              connection_pid: connection_pid
            ),
          tasks: %{connect: connection_task_ref}
        } = state,
        connection_task_ref,
        result
      ) do
    handle_connect_task_result(state, connection_ref, connection_pid, connection_task_ref, result)
  end

  def handle_task_result(
        %__MODULE__{
          state:
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
            | state:
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

          playbook_ref = make_ref()

          %__MODULE__{
            state
            | state:
                connected_state(
                  connection_ref: connection_ref,
                  connection_pid: connection_pid
                ),
              ansible_playbooks: [{playbook_run, playbook_ref} | state.ansible_playbooks],
              actions: [
                {:run_playbook, playbook_run, playbook_ref}
              ]
          }
        end

      {:ok, _stdout, stderr, _exit_code} ->
        Logger.info(
          "Server manager does not have sudo access to server #{server.id} as #{state.username}; connected with problems"
        )

        %__MODULE__{
          state
          | state:
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
          | state:
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
          state: connected_state(),
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
          state: connected_state(),
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
          | problems: problems ++ detect_server_properties_mismatches(state.server, facts)
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
          | state:
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

        %__MODULE__{
          state
          | state: connection_failed_state(reason: reason)
        }
    end
    |> drop_task(:connect, connection_task_ref)
  end

  @spec ansible_playbook_completed(t(), UUID.t(), reference()) :: t()
  def ansible_playbook_completed(
        %__MODULE__{
          state: connected_state(connection_pid: connection_pid, connection_ref: connection_ref),
          ansible_playbooks: [
            {%AnsiblePlaybookRun{id: run_id} = run, run_ref} | remaining_playbooks
          ]
        } = state,
        run_id,
        run_ref
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
                | state:
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
        %__MODULE__{server: %Server{class: %Class{id: class_id}}, problems: problems} = state,
        %Class{id: class_id} = class
      ) do
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
        problems:
          problems
          |> Enum.filter(fn problem -> elem(problem, 0) != :expected_property_mismatch end)
          |> Enum.concat(detect_server_properties_mismatches(state.server, facts))
    }
  end

  @spec connection_crashed(t(), pid(), term()) :: t()
  def connection_crashed(
        %__MODULE__{state: connected_state(connection_pid: connection_pid)} = state,
        connection_pid,
        reason
      ) do
    :ets.delete(state.storage, :facts)
    server = state.server
    Logger.info("Connection to server #{server.id} crashed because: #{inspect(reason)}")
    %__MODULE__{state | state: :disconnected}
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

  # TODO: perform new check when class/server is modified
  defp detect_server_properties_mismatches(_server, nil), do: []

  defp detect_server_properties_mismatches(server, facts),
    do:
      []
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
