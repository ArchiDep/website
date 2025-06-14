defmodule ArchiDep.Servers.ServerManagerState do
  require Logger
  require Record
  import ArchiDep.Helpers.SchemaHelpers, only: [trim_to_nil: 1]
  alias ArchiDep.Helpers.NetHelpers
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerConnection
  alias ArchiDep.Students.Schemas.Class
  alias Ecto.UUID

  Record.defrecord(:connecting_state,
    connection_ref: nil,
    connection_pid: nil,
    connection_task_ref: nil
  )

  Record.defrecord(:connection_failed_state, reason: "could not connect")

  Record.defrecord(:checking_access_state,
    connection_ref: nil,
    connection_pid: nil
  )

  Record.defrecord(:connected_state, connection_ref: nil, connection_pid: nil)

  @enforce_keys [:state, :server, :username, :storage, :actions, :tasks, :problems]
  defstruct [:state, :server, :username, :storage, actions: [], tasks: %{}, problems: []]

  @type t :: %__MODULE__{
          state:
            :not_connected
            | connecting_state()
            | connection_failed_state()
            | connected_state()
            | :disconnected,
          server: Server.t(),
          username: String.t(),
          storage: :ets.tid(),
          actions: list(action()),
          tasks: %{atom() => reference()},
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

  @type connect_action ::
          {:connect,
           (t(),
            (:inet.ip_address(), network_port(), String.t(), ServerConnection.connect_options() ->
               Task.t()) ->
              t())}
  @type demonitor_action :: {:demonitor, reference()}
  @type gather_facts_action ::
          {:gather_facts, (t(), (String.t() -> Task.t()) -> t())}
  @type request_load_average :: {:request_load_average, reference()}
  @type run_command_action ::
          {:run_command, (t(), (String.t(), pos_integer() -> Task.t()) -> t())}
  @type run_playbook_action ::
          {:run_playbook,
           (t(), (AnsiblePlaybook.t(), String.t(), Runner.ansible_variables() -> Task.t()) -> t())}
  @type track_action :: {:track, String.t(), UUID.t(), map()}
  @type action ::
          demonitor_action()
          | request_load_average()
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

  @spec init(UUID.t()) :: t()
  def init(server_id) do
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
      username: username,
      storage: storage,
      actions: [
        {:track, "servers", server.id, %{state: :not_connected}}
      ],
      tasks: %{},
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
           fn state, task_factory ->
             task = task_factory.(host, port, username, silently_accept_hosts: true)
             %__MODULE__{state | tasks: Map.put(state.tasks, :connect, task.ref)}
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
    server = state.server

    case result do
      :ok ->
        Logger.info("Server manager is connected to server #{server.id}; checking sudo access...")

        %__MODULE__{
          state
          | state:
              checking_access_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              {:run_command,
               fn state, task_factory ->
                 task = task_factory.("sudo ls", 10_000)
                 %__MODULE__{state | tasks: Map.put(state.tasks, :check_access, task.ref)}
               end}
            ]
        }

      {:error, reason} ->
        Logger.info(
          "Server manager could not connect to server #{server.id} because #{inspect(reason)}"
        )

        %__MODULE__{
          state
          | state: connection_failed_state(reason: reason)
        }
    end
    |> drop_task(:connect, connection_task_ref)
  end

  @spec handle_task_result(t(), reference(), term()) :: t()
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
        Logger.info("Server manager has sudo access to server #{server.id}; gathering facts...")

        %__MODULE__{
          state
          | state:
              connected_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              {:request_load_average, connection_ref},
              {:gather_facts,
               fn state, task_factory ->
                 task = task_factory.(state.username)
                 %__MODULE__{state | tasks: Map.put(state.tasks, :gather_facts, task.ref)}
               end}
            ]
        }

      {:ok, _stdout, stderr, _exit_code} ->
        Logger.info(
          "Server manager does not have sudo access to server #{server.id}; connected with problems"
        )

        %__MODULE__{
          state
          | state:
              connected_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              {:request_load_average, connection_ref}
            ],
            problems: [
              {:missing_sudo_access, server.username, String.trim(stderr)}
            ]
        }

      {:error, reason} ->
        Logger.error(
          "Server manager could not check sudo access to server #{server.id} because #{inspect(reason)}; connected with problems"
        )

        %__MODULE__{
          state
          | state:
              connected_state(
                connection_ref: connection_ref,
                connection_pid: connection_pid
              ),
            actions: [
              {:request_load_average, connection_ref}
            ],
            problems: [
              {:sudo_access_check_failed, reason}
            ]
        }
    end
    |> drop_task(:check_access, check_access_ref)
  end

  @spec handle_task_result(t(), reference(), term()) :: t()
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

  @spec receive_load_average(
          t(),
          reference(),
          {float(), float(), float(), DateTime.t(), DateTime.t()}
        ) :: t()
  def receive_load_average(
        %__MODULE__{state: connected_state(connection_ref: connection_ref)} = state,
        connection_ref,
        {one_minute, five_minutes, fifteen_minutes, before_call, after_call}
      ) do
    server = state.server

    Logger.info(
      "Received load average from server #{server.id}: #{one_minute}, #{five_minutes}, #{fifteen_minutes} (between #{before_call} and #{after_call})"
    )

    state
  end

  defp drop_task(%__MODULE__{actions: actions, tasks: tasks} = state, key, ref) do
    case Map.get(tasks, key) do
      nil ->
        state

      ^ref ->
        %__MODULE__{state | tasks: Map.delete(tasks, key), actions: [{:demonitor, ref} | actions]}
    end
  end

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
