defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.ServersFactory

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

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server, problems: [server_ansible_playbook_failed(failed_run)])
               )
             ],
             problems: [server_ansible_playbook_failed(failed_run)]
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

  test "a server manager drops specific problems when the connection becomes idle", %{
    connection_idle: connection_idle
  } do
    server =
      build_active_server(
        active: true,
        ssh_port: 2222,
        username: "chuck",
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        server: server,
        username: "chuck",
        problems: [
          {:server_ansible_playbook_failed, "setup", :failed,
           %{
             changed: 1,
             failures: 0,
             ignored: 0,
             ok: 5,
             rescued: 0,
             skipped: 0,
             unreachable: 0
           }},
          {:server_authentication_failed, :username, "Authentication error"},
          {:server_connection_refused, {127, 0, 0, 1}, 22, :username, server.app_username},
          {:server_connection_timed_out, {127, 0, 0, 1}, 22, :username, server.app_username},
          {:server_expected_property_mismatch, :cpu_cores, 4, 8},
          {:server_fact_gathering_failed, "Fact gathering error"},
          {:server_missing_sudo_access, "chuck", "Missing sudo access"},
          {:server_open_ports_check_failed, [{80, "Port closed"}, {443, "Port closed"}]},
          {:server_port_testing_script_failed, {:exit, 1, "Script error"}},
          {:server_reconnection_failed, "Reconnection error"},
          {:server_sudo_access_check_failed, "chuck", "Sudo check error"}
        ],
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
               problems: [
                 {:server_ansible_playbook_failed, "setup", :failed,
                  %{
                    changed: 1,
                    failures: 0,
                    ignored: 0,
                    ok: 5,
                    rescued: 0,
                    skipped: 0,
                    unreachable: 0
                  }},
                 {:server_expected_property_mismatch, :cpu_cores, 4, 8},
                 {:server_fact_gathering_failed, "Fact gathering error"},
                 {:server_open_ports_check_failed, [{80, "Port closed"}, {443, "Port closed"}]},
                 {:server_port_testing_script_failed, {:exit, 1, "Script error"}}
               ]
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

    expected_retrying = %{retrying | backoff: 1}

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

    assert_in_delta DateTime.diff(now, time, :second), 0, 50

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

    assert_in_delta DateTime.diff(now, time, :second), 0, 50

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 1,
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

  defp server_ansible_playbook_failed(ansible_playbook_run),
    do:
      {:server_ansible_playbook_failed, ansible_playbook_run.playbook, :failed,
       ansible_stats(ansible_playbook_run)}

  defp ansible_stats(ansible_playbook_run),
    do: %{
      changed: ansible_playbook_run.stats_changed,
      failures: ansible_playbook_run.stats_failures,
      ignored: ansible_playbook_run.stats_ignored,
      ok: ansible_playbook_run.stats_ok,
      rescued: ansible_playbook_run.stats_rescued,
      skipped: ansible_playbook_run.stats_skipped,
      unreachable: ansible_playbook_run.stats_unreachable
    }

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
end
