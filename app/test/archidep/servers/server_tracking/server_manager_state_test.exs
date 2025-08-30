defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.ServersFactory
  alias Phoenix.Token

  setup :verify_on_exit!

  setup_all do
    %{
      init: protect({ServerManagerState, :init, 2}, ServerManagerBehaviour),
      online?: protect({ServerManagerState, :online?, 1}, ServerManagerBehaviour),
      connection_idle: protect({ServerManagerState, :connection_idle, 2}, ServerManagerBehaviour),
      retry_connecting:
        protect({ServerManagerState, :retry_connecting, 2}, ServerManagerBehaviour),
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "initialize a server manager for a new server", %{init: init} do
    server = generate_server!()

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [track_server_action(server, real_time_state(server))]
           }
  end

  test "initializing a server manager for a server that has already been set up uses the app username instead of the username",
       %{init: init} do
    now = DateTime.utc_now()
    server = generate_server!(set_up_at: now)

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.app_username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server,
                   conn_params: conn_params(server, username: server.app_username),
                   set_up_at: now
                 )
               )
             ]
           }
  end

  test "initializing a server with a failed setup ansible playbook run indicates a problem", %{
    init: init
  } do
    server = generate_server!()
    failed_run = ServersFactory.insert(:ansible_playbook_run, server: server, state: :failed)
    problem = ServersFactory.server_ansible_playbook_failed_problem(playbook_run: failed_run)

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server, problems: [problem])
               )
             ],
             problems: [problem]
           }
  end

  test "check whether a server is online", %{online?: online?} do
    build_state = fn connection_state ->
      ServersFactory.build(:server_manager_state, connection_state: connection_state)
    end

    state = build_state.(ServersFactory.random_connected_state())
    assert online?.(state) == true

    for state <-
          [
            ServersFactory.random_not_connected_state(),
            ServersFactory.random_connecting_state(),
            ServersFactory.random_retry_connecting_state(),
            ServersFactory.random_reconnecting_state(),
            ServersFactory.random_connection_failed_state(),
            ServersFactory.random_disconnected_state()
          ] do
      assert online?.(build_state.(state)) == false
    end
  end

  test "a not connected server manager for an active server connects when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: 2222,
        username: "alice",
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        server: server,
        username: "alice",
        version: 24
      )

    result = connection_idle.(initial_state, self())

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: false
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions
           }

    assert_connect_fn(connect_fn, result, "alice", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 25
              ), %ServerManagerState{result | version: 25}}
  end

  test "a disconnected server manager for an active server connects when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: 2222,
        username: "bob",
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        server: server,
        username: "bob",
        version: 24
      )

    result = connection_idle.(initial_state, self())

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: false
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions
           }

    assert_connect_fn(connect_fn, result, "bob", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 25
              ), %ServerManagerState{result | version: 25}}
  end

  test "specific problems are dropped when the connection becomes idle", %{
    connection_idle: connection_idle
  } do
    server =
      build_active_server(
        active: true,
        ssh_port: 2222,
        username: "chuck",
        set_up_at: nil
      )

    dropped_problems =
      Enum.shuffle([
        ServersFactory.server_authentication_failed_problem(),
        ServersFactory.server_missing_sudo_access_problem(),
        ServersFactory.server_reconnection_failed_problem(),
        ServersFactory.server_sudo_access_check_failed_problem()
      ])

    kept_problems =
      Enum.shuffle([
        ServersFactory.server_ansible_playbook_failed_problem(),
        ServersFactory.server_connection_refused_problem(),
        ServersFactory.server_connection_timed_out_problem(),
        ServersFactory.server_expected_property_mismatch_problem(),
        ServersFactory.server_fact_gathering_failed_problem(),
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ])

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        server: server,
        username: "chuck",
        problems: apply(&Kernel.++/2, Enum.shuffle([dropped_problems, kept_problems])),
        version: 24
      )

    result = connection_idle.(initial_state, self())

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: false
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions,
               problems: kept_problems
           }

    assert_connect_fn(connect_fn, result, "chuck", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                problems: result.problems,
                version: 25
              ), %ServerManagerState{result | version: 25}}
  end

  test "a not connected server manager for an inactive server remains not connected when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server = ServersFactory.build(:server, active: false, username: "alice", set_up_at: nil)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        server: server,
        username: "alice",
        version: 42
      )

    result = connection_idle.(initial_state, self())

    pid = self()

    assert result == %ServerManagerState{
             initial_state
             | connection_state: not_connected_state(connection_pid: self()),
               actions: [{:monitor, pid}]
           }
  end

  test "a disconnected server manager for an inactive server transitions to the not connected state when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server = ServersFactory.build(:server, active: false, username: "alice", set_up_at: nil)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        server: server,
        username: "alice",
        version: 42
      )

    result = connection_idle.(initial_state, self())

    pid = self()

    assert %{
             actions:
               [{:monitor, ^pid}, {:update_tracking, "servers", update_tracking_fn}] = actions
           } =
             result

    assert result == %ServerManagerState{
             initial_state
             | connection_state: not_connected_state(connection_pid: self()),
               actions: actions
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server, connection_state: result.connection_state, version: 43),
              %ServerManagerState{result | version: 43}}
  end

  test "automatically retry connecting to a server after a delay", %{
    retry_connecting: retry_connecting
  } do
    server =
      build_active_server(
        ssh_port: 2223,
        username: "dave",
        set_up_at: nil
      )

    retry_timer = Process.send_after(self(), :retry, 30_000)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        server: server,
        username: "dave",
        retry_timer: retry_timer,
        version: 30
      )

    retry_connecting_state(retrying: retrying) = initial_state.connection_state

    result = retry_connecting.(initial_state, false)

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: ^retrying
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^retry_timer},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions,
               retry_timer: nil
           }

    assert_connect_fn(connect_fn, result, "dave", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{result | version: 31}}
  end

  test "manually retrying to connect to a server resets the backoff delay", %{
    retry_connecting: retry_connecting
  } do
    server =
      build_active_server(
        ssh_port: 2223,
        username: "dave",
        set_up_at: nil
      )

    retry_timer = Process.send_after(self(), :retry, 30_000)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        server: server,
        username: "dave",
        retry_timer: retry_timer,
        version: 30
      )

    retry_connecting_state(retrying: retrying) = initial_state.connection_state

    result = retry_connecting.(initial_state, true)

    test_pid = self()

    expected_retrying = %{retrying | backoff: 0}

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: ^expected_retrying
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^retry_timer},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions,
               retry_timer: nil
           }

    assert_connect_fn(connect_fn, result, "dave", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{result | version: 31}}
  end

  test "retry connecting to a server after a connection failure", %{
    retry_connecting: retry_connecting
  } do
    server =
      build_active_server(
        ssh_port: 2223,
        username: "frank",
        set_up_at: nil
      )

    retry_timer = Process.send_after(self(), :retry, 30_000)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connection_failed_state(),
        server: server,
        username: "frank",
        retry_timer: retry_timer,
        version: 30
      )

    manual = FactoryHelpers.bool()
    result = retry_connecting.(initial_state, manual)

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 retrying: false
               ) = connection_state,
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^retry_timer},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions,
               retry_timer: nil
           }

    assert_connect_fn(connect_fn, result, "frank", test_pid)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{result | version: 31}}
  end

  test "retry connecting in the wrong state does nothing", %{retry_connecting: retry_connecting} do
    server = build_active_server()

    for connection_state <-
          [
            ServersFactory.random_not_connected_state(),
            ServersFactory.random_connecting_state(),
            ServersFactory.random_connected_state(),
            ServersFactory.random_reconnecting_state(),
            ServersFactory.random_disconnected_state()
          ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          server: server,
          username: "frank",
          version: 30
        )

      assert {^initial_state, log} =
               with_log(fn -> retry_connecting.(initial_state, true) end)

      assert log =~ "Ignore request to retry connecting"

      assert {^initial_state, log2} =
               with_log(fn -> retry_connecting.(initial_state, false) end)

      assert log2 =~ "Ignore request to retry connecting"
    end
  end

  test "check sudo access after successful connection", %{handle_task_result: handle_task_result} do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_ref: connection_ref, connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        version: 10
      )

    now = DateTime.utc_now()
    result = handle_task_result.(initial_state, fake_connect_task_ref, :ok)

    assert %{
             connection_state:
               connected_state(
                 connection_ref: ^connection_ref,
                 connection_pid: ^connection_pid,
                 time: time
               ),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(
                   connection_ref: connection_ref,
                   connection_pid: connection_pid,
                   time: time
                 ),
               actions: actions,
               tasks: %{},
               version: 10
           }

    fake_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "sudo -n ls", 10_000 ->
             fake_task
           end) == %ServerManagerState{result | tasks: %{check_access: fake_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: 11
              ), %ServerManagerState{result | version: 11}}
  end

  test "connection-related problems are dropped on successful connection", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_ref: connection_ref, connection_pid: connection_pid) = connecting

    connection_problems =
      Enum.shuffle([
        ServersFactory.server_connection_refused_problem(),
        ServersFactory.server_connection_timed_out_problem()
      ])

    other_problems =
      Enum.shuffle([
        ServersFactory.server_ansible_playbook_failed_problem(),
        ServersFactory.server_authentication_failed_problem(),
        ServersFactory.server_expected_property_mismatch_problem(),
        ServersFactory.server_fact_gathering_failed_problem(),
        ServersFactory.server_missing_sudo_access_problem(),
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem(),
        ServersFactory.server_reconnection_failed_problem(),
        ServersFactory.server_sudo_access_check_failed_problem()
      ])

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems: apply(&Kernel.++/2, Enum.shuffle([connection_problems, other_problems])),
        version: 10
      )

    now = DateTime.utc_now()
    result = handle_task_result.(initial_state, fake_connect_task_ref, :ok)

    assert %{
             connection_state:
               connected_state(
                 connection_ref: ^connection_ref,
                 connection_pid: ^connection_pid,
                 time: time
               ),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(
                   connection_ref: connection_ref,
                   connection_pid: connection_pid,
                   time: time
                 ),
               actions: actions,
               tasks: %{},
               problems: other_problems,
               version: 10
           }

    fake_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "sudo -n ls", 10_000 ->
             fake_task
           end) == %ServerManagerState{result | tasks: %{check_access: fake_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: 11
              ), %ServerManagerState{result | version: 11}}
  end

  test "a connection authentication failure stops the connection process", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        version: 9
      )

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_connect_task_ref,
          {:error, :authentication_failed}
        )
      end)

    assert log =~ ~r"Server manager could not connect .* because authentication failed"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connection_failed_state(
                   connection_pid: connection_pid,
                   reason: :authentication_failed
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_authentication_failed, :username, server.username}
               ],
               version: 9
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: 10
              ), %ServerManagerState{result | version: 10}}
  end

  test "a connection authentication failure as the application user stops the connection process",
       %{
         handle_task_result: handle_task_result
       } do
    server = build_active_server(set_up_at: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.app_username,
        tasks: %{connect: fake_connect_task_ref},
        version: 9
      )

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_connect_task_ref,
          {:error, :authentication_failed}
        )
      end)

    assert log =~ ~r"Server manager could not connect .* because authentication failed"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connection_failed_state(
                   connection_pid: connection_pid,
                   reason: :authentication_failed
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_authentication_failed, :app_username, server.app_username}
               ],
               version: 9
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: 10
              ), %ServerManagerState{result | version: 10}}
  end

  test "schedule a connection retry after a connection timeout", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref}
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :timeout}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :timeout
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_connection_timed_out, server.ip_address.address, server.ssh_port,
                  server.username}
               ]
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous connection problems are dropped after a connection timeout", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems:
          Enum.shuffle([
            ServersFactory.server_connection_refused_problem(),
            ServersFactory.server_connection_timed_out_problem()
          ])
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :timeout}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :timeout
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_connection_timed_out, server.ip_address.address, server.ssh_port,
                  server.username}
               ]
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "schedule a connection retry after the connection was refused", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref}
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :econnrefused}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :econnrefused
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_connection_refused, server.ip_address.address, server.ssh_port,
                  server.username}
               ]
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous connection problems are dropped after the connection was refused", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems:
          Enum.shuffle([
            ServersFactory.server_connection_refused_problem(),
            ServersFactory.server_connection_timed_out_problem()
          ])
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :econnrefused}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :econnrefused
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_connection_refused, server.ip_address.address, server.ssh_port,
                  server.username}
               ]
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "schedule a connection retry after a generic connection failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        version: 9
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :foo}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :foo
                   }
                 ),
               actions: actions,
               tasks: %{},
               version: 9
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: 10
              ), %ServerManagerState{result | version: 10}}
  end

  test "previous connection problems are dropped after a generic connection failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems:
          Enum.shuffle([
            ServersFactory.server_connection_refused_problem(),
            ServersFactory.server_connection_timed_out_problem()
          ]),
        version: 9
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, :foo}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :foo
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: [],
               version: 9
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: 10
              ), %ServerManagerState{result | version: 10}}
  end

  test "schedule another connection retry after a connection error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: %{retry: 1, backoff: 0}})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref}
      )

    now = DateTime.utc_now()

    connection_error =
      Enum.random([:timeout, :econnrefused, "Oops"])

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, connection_error}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions,
             problems: problems
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 2,
                     backoff: 1,
                     time: time,
                     in_seconds: 5,
                     reason: connection_error
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: problems
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 5_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "schedule a fifth connection retry after a connection error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: %{retry: 4, backoff: 3}})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref}
      )

    now = DateTime.utc_now()

    connection_error =
      Enum.random([:timeout, :econnrefused, "Oops"])

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, connection_error}
      )

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions,
             problems: problems
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 5

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 5,
                     backoff: 4,
                     time: time,
                     in_seconds: 20,
                     reason: connection_error
                   }
                 ),
               actions: actions,
               tasks: %{},
               problems: problems
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :retry_connecting, 20_000 ->
             fake_timer_ref
           end) ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "schedule a connection retry after a reconnection timeout", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    reconnecting = ServersFactory.random_reconnecting_state()
    reconnecting_state(connection_pid: connection_pid) = reconnecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: reconnecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref}
      )

    connection_failure_reason = ServersFactory.random_connection_failure_reason()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, connection_failure_reason}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connection_failed_state(
                   connection_pid: connection_pid,
                   reason: connection_failure_reason
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_reconnection_failed, connection_failure_reason}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous problems are dropped after a reconnection timeout", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_connect_task_ref = make_ref()

    reconnecting = ServersFactory.random_reconnecting_state()
    reconnecting_state(connection_pid: connection_pid) = reconnecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: reconnecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems:
          Enum.shuffle([
            ServersFactory.server_ansible_playbook_failed_problem(),
            ServersFactory.server_authentication_failed_problem(),
            ServersFactory.server_connection_refused_problem(),
            ServersFactory.server_connection_timed_out_problem(),
            ServersFactory.server_expected_property_mismatch_problem(),
            ServersFactory.server_fact_gathering_failed_problem(),
            ServersFactory.server_missing_sudo_access_problem(),
            ServersFactory.server_open_ports_check_failed_problem(),
            ServersFactory.server_port_testing_script_failed_problem(),
            ServersFactory.server_reconnection_failed_problem(),
            ServersFactory.server_sudo_access_check_failed_problem()
          ])
      )

    connection_failure_reason = ServersFactory.random_connection_failure_reason()

    result =
      handle_task_result.(
        initial_state,
        fake_connect_task_ref,
        {:error, connection_failure_reason}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connection_failed_state(
                   connection_pid: connection_pid,
                   reason: connection_failure_reason
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_reconnection_failed, connection_failure_reason}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "gather facts after sudo access has been confirmed with the application user", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:gather_facts, gather_facts_fn},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_facts_task = Task.completed(:fake)
    app_username = server.app_username

    assert gather_facts_fn.(result, fn ^app_username -> fake_facts_task end) ==
             %ServerManagerState{result | tasks: %{gather_facts: fake_facts_task.ref}}

    fake_loadavg_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
             fake_loadavg_task
           end) == %ServerManagerState{result | tasks: %{get_load_average: fake_loadavg_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: connected,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "run the setup playbook after sudo access has been confirmed with the normal user", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_playbook,
                  %{
                    digest: digest,
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               ansible_playbook: {playbook_run, nil},
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 5

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             server: server,
             server_id: server.id,
             state: :pending,
             started_at: playbook_created_at,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: connected,
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup process is stopped if the user does not have sudo access", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_stderr = Faker.Lorem.sentence()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), check_access_stderr, Faker.random_between(1, 255)}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_missing_sudo_access, server.username, check_access_stderr}]
           }

    fake_loadavg_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
             fake_loadavg_task
           end) == %ServerManagerState{result | tasks: %{get_load_average: fake_loadavg_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "fact gathering is not triggered if the application user does not have sudo access", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_stderr = Faker.Lorem.sentence()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), check_access_stderr, Faker.random_between(1, 255)}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_missing_sudo_access, server.app_username, check_access_stderr}]
           }

    fake_loadavg_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
             fake_loadavg_task
           end) == %ServerManagerState{result | tasks: %{get_load_average: fake_loadavg_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup process is stopped if sudo access cannot be checked", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_check_access_task_ref,
          {:error, check_access_error}
        )
      end)

    assert log =~ "Server manager could not check sudo access to server #{server.id}"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_sudo_access_check_failed, server.username, check_access_error}]
           }

    fake_loadavg_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
             fake_loadavg_task
           end) == %ServerManagerState{result | tasks: %{get_load_average: fake_loadavg_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "fact gathering is not triggered if sudo access cannot be checked", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_check_access_task_ref,
          {:error, check_access_error}
        )
      end)

    assert log =~ "Server manager could not check sudo access to server #{server.id}"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_sudo_access_check_failed, server.app_username, check_access_error}
               ]
           }

    fake_loadavg_task = Task.completed(:fake)

    assert run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
             fake_loadavg_task
           end) == %ServerManagerState{result | tasks: %{get_load_average: fake_loadavg_task.ref}}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "receive load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "0.65 0.43 0.21 1/436 761182\n", "", 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive malformed load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "oops", "", 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive failed load average from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "", "Oops\n", Faker.random_between(1, 255)}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive load average error from the server", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:error, Faker.Lorem.sentence()}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  test "receive load average from the server while another task is in progress", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_ref = make_ref()
    fake_get_load_average_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_ref, get_load_average: fake_get_load_average_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_get_load_average_ref,
        {:ok, "0.65 0.43 0.21 1/436 761182\n", "", 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_get_load_average_ref},
                 {:send_message, send_message_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{check_access: fake_check_access_ref}
           }

    fake_timer_ref = make_ref()

    assert send_message_fn.(result, fn :measure_load_average, 20_000 ->
             fake_timer_ref
           end) == %ServerManagerState{result | load_average_timer: fake_timer_ref}
  end

  defp assert_connect_fn(connect_fn, state, username, test_pid) do
    task = Task.completed(:fake)

    assert connect_fn.(state, fn host, port, username, opts ->
             send(test_pid, {:connect_fn_called, host, port, username, opts})
             task
           end) == %ServerManagerState{state | tasks: %{connect: task.ref}}

    expected_host = state.server.ip_address.address
    expected_port = state.server.ssh_port || 22

    assert_receive {:connect_fn_called, ^expected_host, ^expected_port, ^username,
                    silently_accept_hosts: true}
  end

  defp build_active_server(opts \\ []) do
    group = ServersFactory.build(:server_group, active: true, servers_enabled: true)

    root = FactoryHelpers.bool()

    member =
      if root do
        nil
      else
        ServersFactory.build(:server_group_member, active: true, group: group)
      end

    owner = ServersFactory.build(:server_owner, active: true, root: root, group_member: member)

    ServersFactory.build(
      :server,
      Keyword.merge([active: true, group: group, owner: owner], opts)
    )
  end

  defp insert_active_server!(opts) do
    class = CourseFactory.insert(:class, active: true, servers_enabled: true)
    group = Repo.get!(ServerGroup, class.id)

    root = FactoryHelpers.bool()

    member =
      if root do
        nil
      else
        user_account = AccountsFactory.insert(:user_account)
        user = Repo.get!(User, user_account.id)

        student =
          CourseFactory.insert(:student,
            active: true,
            class: class,
            class_id: group.id,
            user: user,
            user_id: user.id
          )

        Repo.get!(ServerGroupMember, student.id)
      end

    owner =
      if member do
        Repo.update_all(UserAccount, set: [preregistered_user_id: member.id])
        Repo.get!(ServerOwner, member.owner_id)
      else
        user_account = AccountsFactory.insert(:user_account, active: true, root: true)
        Repo.get!(ServerOwner, user_account.id)
      end

    ServersFactory.insert(
      :server,
      Keyword.merge(
        [
          active: true,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        ],
        opts
      )
    )
  end

  defp generate_server!(attrs \\ []) do
    user_account = AccountsFactory.insert(:user_account)
    course = CourseFactory.insert(:class, servers_enabled: true)

    incomplete_server =
      ServersFactory.insert(
        :server,
        Keyword.merge(
          [active: true, owner_id: user_account.id, group_id: course.id, set_up_at: nil],
          attrs
        )
      )

    fetch_server!(incomplete_server.id)
  end

  defp track_server_action(server, state), do: {:track, "servers", server.id, state}

  defp real_time_state(server, attrs! \\ []) do
    {connection_state, attrs!} =
      Keyword.pop_lazy(attrs!, :connection_state, fn -> not_connected_state() end)

    {conn_params, attrs!} = Keyword.pop_lazy(attrs!, :conn_params, fn -> conn_params(server) end)
    {current_job, attrs!} = Keyword.pop(attrs!, :current_job, nil)
    {problems, attrs!} = Keyword.pop(attrs!, :problems, [])
    {set_up_at, attrs!} = Keyword.pop_lazy(attrs!, :set_up_at, fn -> server.set_up_at end)
    {version, attrs!} = Keyword.pop(attrs!, :version, 0)

    [] = Keyword.keys(attrs!)

    %ServerRealTimeState{
      connection_state: connection_state,
      name: server.name,
      conn_params: conn_params,
      username: server.username,
      app_username: server.app_username,
      current_job: current_job,
      problems: problems,
      set_up_at: set_up_at,
      version: version
    }
  end

  defp conn_params(server, attrs! \\ []) do
    {username, attrs!} = Keyword.pop(attrs!, :username, server.username)

    [] = Keyword.keys(attrs!)

    {server.ip_address.address, server.ssh_port || 22, username}
  end

  defp fetch_server!(id),
    do:
      Repo.one!(
        from s in Server,
          join: o in assoc(s, :owner),
          left_join: ogm in assoc(o, :group_member),
          left_join: ogmg in assoc(ogm, :group),
          join: g in assoc(s, :group),
          join: gesp in assoc(g, :expected_server_properties),
          join: ep in assoc(s, :expected_properties),
          left_join: lkp in assoc(s, :last_known_properties),
          where: s.id == ^id,
          preload: [
            group: {g, expected_server_properties: gesp},
            expected_properties: ep,
            last_known_properties: lkp,
            owner: {o, group_member: {ogm, group: ogmg}}
          ]
      )

  defp ssh_public_key,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:ssh_public_key)
end
