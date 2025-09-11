defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandleTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ArchiDep.Support.TelemetryTestHelpers
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Phoenix.PubSub
  alias Phoenix.Token

  @pubsub ArchiDep.PubSub

  @no_server_properties [
    hostname: nil,
    machine_id: nil,
    cpus: nil,
    cores: nil,
    vcpus: nil,
    memory: nil,
    swap: nil,
    system: nil,
    architecture: nil,
    os_family: nil,
    distribution: nil,
    distribution_release: nil,
    distribution_version: nil
  ]

  setup :verify_on_exit!

  setup_all do
    %{
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "check sudo access after successful connection",
       %{handle_task_result: handle_task_result} = context do
    attach_telemetry_handler!(context, [:archidep, :servers, :tracking, :connected])

    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()
    fake_event = EventsFactory.insert(:stored_event)
    fake_event_reference = StoredEvent.to_reference(fake_event)

    connecting =
      ServersFactory.random_connecting_state(%{
        retrying: false,
        causation_event: fake_event_reference
      })

    connecting_state(
      connection_ref: connection_ref,
      connection_pid: connection_pid,
      time: connecting_time
    ) = connecting

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

    [connection_event] = fetch_new_stored_events([fake_event])

    connection_event_ref =
      assert_server_connected_event!(connection_event, server, now, fake_event)

    assert %{
             connection_state: connected_state(time: time),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(
                   connection_ref: connection_ref,
                   connection_pid: connection_pid,
                   time: time,
                   connection_event: connection_event_ref
                 ),
               actions: actions,
               tasks: %{},
               version: 10
           }

    fake_task = Task.completed(:fake)

    check_access_result =
      run_command_fn.(result, fn "sudo -n ls", 10_000 ->
        fake_task
      end)

    assert check_access_result == %ServerManagerState{
             result
             | tasks: %{check_access: fake_task.ref}
           }

    assert update_tracking_fn.(check_access_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :checking_access,
                version: 11
              ), %ServerManagerState{check_access_result | version: 11}}

    event_data = assert_telemetry_event!([:archidep, :servers, :tracking, :connected])
    assert %{measurements: %{duration: connection_duration}} = event_data

    assert_in_delta DateTime.diff(now, connecting_time, :millisecond) / 1000,
                    connection_duration,
                    1

    assert event_data == %{
             measurements: %{duration: connection_duration},
             metadata: %{},
             config: nil
           }
  end

  test "check sudo access after successful reconnection",
       %{handle_task_result: handle_task_result} = context do
    attach_telemetry_handler!(context, [:archidep, :servers, :tracking, :connected])

    server = insert_active_server!(set_up_at: true, ssh_port: true)

    fake_connect_task_ref = make_ref()
    fake_event = EventsFactory.insert(:stored_event)
    fake_event_reference = StoredEvent.to_reference(fake_event)

    reconnecting =
      ServersFactory.random_reconnecting_state(causation_event: fake_event_reference)

    reconnecting_state(
      connection_ref: connection_ref,
      connection_pid: connection_pid,
      time: connecting_time
    ) = reconnecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: reconnecting,
        server: server,
        username: server.app_username,
        tasks: %{connect: fake_connect_task_ref},
        version: 10
      )

    now = DateTime.utc_now()
    result = handle_task_result.(initial_state, fake_connect_task_ref, :ok)

    [connection_event] = fetch_new_stored_events([fake_event])

    connection_event_ref =
      assert_server_connected_event!(connection_event, server, now, fake_event)

    assert %{
             connection_state: connected_state(time: time),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(
                   connection_ref: connection_ref,
                   connection_pid: connection_pid,
                   time: time,
                   connection_event: connection_event_ref
                 ),
               actions: actions,
               tasks: %{},
               version: 10
           }

    fake_task = Task.completed(:fake)

    check_access_result =
      run_command_fn.(result, fn "sudo -n ls", 10_000 ->
        fake_task
      end)

    assert check_access_result == %ServerManagerState{
             result
             | tasks: %{check_access: fake_task.ref}
           }

    assert update_tracking_fn.(check_access_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_access,
                version: 11
              ), %ServerManagerState{check_access_result | version: 11}}

    event_data = assert_telemetry_event!([:archidep, :servers, :tracking, :connected])
    assert %{measurements: %{duration: connection_duration}} = event_data

    assert_in_delta DateTime.diff(now, connecting_time, :millisecond) / 1000,
                    connection_duration,
                    1

    assert event_data == %{
             measurements: %{duration: connection_duration},
             metadata: %{},
             config: nil
           }
  end

  test "connection-related problems are dropped on successful connection", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()

    connecting = ServersFactory.random_connecting_state(%{retrying: false, causation_event: nil})
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

    [connection_event] = fetch_new_stored_events()
    connection_event_ref = assert_server_connected_event!(connection_event, server, now)

    assert %{
             connection_state: connected_state(time: time),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(
                   connection_ref: connection_ref,
                   connection_pid: connection_pid,
                   time: time,
                   connection_event: connection_event_ref
                 ),
               actions: actions,
               tasks: %{},
               problems: other_problems,
               version: 10
           }

    fake_task = Task.completed(:fake)

    check_access_result =
      run_command_fn.(result, fn "sudo -n ls", 10_000 ->
        fake_task
      end)

    assert check_access_result == %ServerManagerState{
             result
             | tasks: %{check_access: fake_task.ref}
           }

    assert update_tracking_fn.(check_access_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :checking_access,
                problems: result.problems,
                version: 11
              ), %ServerManagerState{check_access_result | version: 11}}
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
    assert_no_stored_events!()

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
    assert_no_stored_events!()

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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: 10
              ), %ServerManagerState{send_message_result | version: 10}}
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

    assert_no_stored_events!()

    assert %{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:demonitor, ^fake_connect_task_ref},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: 10
              ), %ServerManagerState{send_message_result | version: 10}}
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

    assert_no_stored_events!()

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

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
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

    assert_no_stored_events!()

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

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

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

    send_message_result =
      send_message_fn.(result, fn :retry_connecting, 20_000 ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
  end

  test "a reconnection failure stops the connection process", %{
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

    assert_no_stored_events!()

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

  test "previous problems are dropped after a reconnection failure", %{
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

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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

    facts_result = gather_facts_fn.(result, fn ^app_username -> fake_facts_task end)

    assert facts_result ==
             %ServerManagerState{result | tasks: %{gather_facts: fake_facts_task.ref}}

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(facts_result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             facts_result
             | tasks: Map.put(facts_result.tasks, :get_load_average, fake_loadavg_task.ref)
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: connected,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :gathering_facts,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
  end

  test "run the setup playbook after sudo access has been confirmed with the normal user", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()
    connected = ServersFactory.random_connected_state(connection_event: fake_connection_event)

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
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [run_started_event] = fetch_new_stored_events([fake_connection_event])

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: Ansible.setup_playbook().digest,
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
             started_at: nil,
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

    assert_no_stored_events!()

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

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
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

    assert_no_stored_events!()

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

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
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

    assert_no_stored_events!()

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

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
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
    assert_no_stored_events!()

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

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
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

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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

  test "run the port testing script after facts have been gathered",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "the connection process is complete after facts have been gathered if open ports have already been checked",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, open_ports_checked_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "detected properties are saved after gathering facts the first time",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: @no_server_properties,
        server_expected_properties: @no_server_properties
      )

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 2,
      "ansible_processor_cores" => 4,
      "ansible_processor_vcpus" => 8,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 4096},
        "swap" => %{"total" => 2048}
      },
      "ansible_system" => "Linux",
      "ansible_architecture" => "x86_64",
      "ansible_os_family" => "Debian",
      "ansible_distribution" => "Ubuntu",
      "ansible_distribution_release" => "noble",
      "ansible_distribution_version" => "24.04"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 2,
                     cores: 4,
                     vcpus: 8,
                     memory: 4096,
                     swap: 2048,
                     system: "Linux",
                     architecture: "x86_64",
                     os_family: "Debian",
                     distribution: "Ubuntu",
                     distribution_release: "noble",
                     distribution_version: "24.04"
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "last known server properties are updated after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: @no_server_properties,
        server_expected_properties: @no_server_properties,
        server_last_known_properties: [
          hostname: "old-hostname",
          machine_id: "old-machine-id",
          cpus: 1,
          cores: 1,
          vcpus: nil,
          memory: 1024,
          swap: 512,
          system: "OldOS",
          architecture: "i386",
          os_family: "OldFamily",
          distribution: "OldDistro",
          distribution_release: nil,
          distribution_version: "0.1"
        ]
      )

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 2,
      "ansible_processor_cores" => 4,
      "ansible_processor_vcpus" => 8,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 4096},
        "swap" => %{"total" => 2048}
      },
      "ansible_system" => "Linux",
      "ansible_architecture" => "x86_64",
      "ansible_os_family" => "Debian",
      "ansible_distribution" => "Ubuntu",
      "ansible_distribution_release" => "noble",
      "ansible_distribution_version" => "24.04"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server: updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: server.last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 2,
                     cores: 4,
                     vcpus: 8,
                     memory: 4096,
                     swap: 2048,
                     system: "Linux",
                     architecture: "x86_64",
                     os_family: "Debian",
                     distribution: "Ubuntu",
                     distribution_release: "noble",
                     distribution_version: "24.04"
                   },
                   last_known_properties_id: server.last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "server property mismatches are detected after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: [
          hostname: nil,
          machine_id: nil,
          cpus: 4,
          cores: 8,
          vcpus: nil,
          memory: 2048,
          swap: nil,
          system: "Windows",
          architecture: "x86_64",
          os_family: nil,
          distribution: nil,
          distribution_release: "bar",
          distribution_version: "0.01"
        ],
        server_expected_properties: [
          hostname: nil,
          machine_id: nil,
          cpus: 2,
          cores: nil,
          vcpus: 8,
          memory: nil,
          swap: 4096,
          system: "Linux",
          architecture: nil,
          os_family: "Debian",
          distribution: "Foo",
          distribution_release: nil,
          distribution_version: "0.02"
        ]
      )

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref},
        problems: [
          ServersFactory.server_expected_property_mismatch_problem(),
          ServersFactory.server_expected_property_mismatch_problem()
        ]
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 4,
      "ansible_processor_cores" => 7,
      "ansible_processor_vcpus" => 9,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 2000},
        "swap" => %{"total" => 4096}
      },
      "ansible_system" => "macOS",
      "ansible_architecture" => "arm64",
      "ansible_os_family" => "DOS"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server: %Server{last_known_properties_id: last_known_properties_id} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 4,
                     cores: 7,
                     vcpus: 9,
                     memory: 2000,
                     swap: 4096,
                     system: "macOS",
                     architecture: "arm64",
                     os_family: "DOS"
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_expected_property_mismatch, :cpus, 2, 4},
                 {:server_expected_property_mismatch, :cores, 8, 7},
                 {:server_expected_property_mismatch, :vcpus, 8, 9},
                 {:server_expected_property_mismatch, :system, "Linux", "macOS"},
                 {:server_expected_property_mismatch, :architecture, "x86_64", "arm64"},
                 {:server_expected_property_mismatch, :os_family, "Debian", "DOS"}
               ]
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "a warning is logged if no previous ansible setup playbook run is found after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_gather_facts_ref,
          {:ok, %{}}
        )
      end)

    assert log =~ "No previous Ansible setup playbook run found for server #{server.id}"

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "the setup playbook is rerun after gathering facts if the previous run failed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :failed,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event, run_started_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: Ansible.setup_playbook().digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.app_username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             server: updated_server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup playbook is rerun after gathering facts if its digest has changed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: <<102, 111, 111>>
    )

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event, run_started_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: Ansible.setup_playbook().digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.app_username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             server: updated_server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "a fact gathering error stops the connection process",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    fact_gathering_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_gather_facts_ref,
          {:error, fact_gathering_error}
        )
      end)

    assert log =~ "Server manager could not gather facts for server #{server.id}"
    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_fact_gathering_failed, fact_gathering_error}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "check open ports after the port testing script has run", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_test_ports_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:check_open_ports, check_open_ports_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_task = Task.completed(:fake)

    server_ip_address = server.ip_address.address

    check_open_ports_result =
      check_open_ports_fn.(result, fn ^server_ip_address, [80, 443, 3000, 3001] ->
        fake_task
      end)

    assert check_open_ports_result ==
             %ServerManagerState{result | tasks: %{check_open_ports: fake_task.ref}}

    assert update_tracking_fn.(check_open_ports_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{check_open_ports_result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on successful run", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    result =
      handle_task_result.(
        initial_state,
        fake_test_ports_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:check_open_ports, check_open_ports_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: []
           }

    fake_task = Task.completed(:fake)

    server_ip_address = server.ip_address.address

    check_open_ports_result =
      check_open_ports_fn.(result, fn ^server_ip_address, [80, 443, 3000, 3001] ->
        fake_task
      end)

    assert check_open_ports_result ==
             %ServerManagerState{result | tasks: %{check_open_ports: fake_task.ref}}

    assert update_tracking_fn.(check_open_ports_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{check_open_ports_result | version: result.version + 1}}
  end

  test "handle port testing script failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    port_testing_stderr = Faker.Lorem.sentence()
    port_testing_exit_code = Faker.random_between(1, 255)

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:ok, Faker.Lorem.sentence(), port_testing_stderr, port_testing_exit_code}
        )
      end)

    assert log =~
             "Port testing script exited with code #{port_testing_exit_code} on server #{server.id}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed,
                  {:exit, port_testing_exit_code, port_testing_stderr}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    port_testing_stderr = Faker.Lorem.sentence()
    port_testing_exit_code = Faker.random_between(1, 255)

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:ok, Faker.Lorem.sentence(), port_testing_stderr, port_testing_exit_code}
        )
      end)

    assert log =~
             "Port testing script exited with code #{port_testing_exit_code} on server #{server.id}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed,
                  {:exit, port_testing_exit_code, port_testing_stderr}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "handle port testing script error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    port_testing_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:error, port_testing_error}
        )
      end)

    assert log =~
             "Port testing script failed on server #{server.id} because: #{inspect(port_testing_error)}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed, {:error, port_testing_error}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    port_testing_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:error, port_testing_error}
        )
      end)

    assert log =~
             "Port testing script failed on server #{server.id} because: #{inspect(port_testing_error)}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed, {:error, port_testing_error}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the connection process is done after open ports have been successfully checked", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: nil)

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref}
      )

    now = DateTime.utc_now()

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert_no_stored_events!()

    assert %{
             server: %{open_ports_checked_at: open_ports_checked_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | open_ports_checked_at: open_ports_checked_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, open_ports_checked_at, :second), 0, 1

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the server is not updated after open ports have been successfully checked if they had already been checked",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    previous_problems =
      [
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ]
      |> Enum.shuffle()
      |> Enum.drop(Faker.random_between(0, 2))

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: []
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous open ports check problems are dropped after a successful check", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: nil)

    previous_problems =
      Enum.shuffle([
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ])

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    now = DateTime.utc_now()

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert_no_stored_events!()

    assert %{
             server: %{open_ports_checked_at: open_ports_checked_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | open_ports_checked_at: open_ports_checked_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{},
               problems: []
           }

    assert_in_delta DateTime.diff(now, open_ports_checked_at, :second), 0, 1

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "handle open ports check failure", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref}
      )

    port_problems = [{80, Faker.Lorem.sentence()}, {3000, :oops}]

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        {:error, port_problems}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_open_ports_check_failed, port_problems}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous open ports check failures are dropped on subsequent failures", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    previous_problems =
      Enum.shuffle([
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ])

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    port_problems = [{80, Faker.Lorem.sentence()}, {3000, :oops}]

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        {:error, port_problems}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_open_ports_check_failed, port_problems}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  defp fetch_new_stored_events(except \\ []) do
    ids_to_exclude = Enum.map(except, & &1.id)

    Repo.all(
      from e in StoredEvent,
        where: e.id not in ^ids_to_exclude,
        order_by: [asc: e.occurred_at]
    )
  end

  defp assert_server_connected_event!(
         %StoredEvent{
           id: event_id,
           data: %{"connection_duration" => connection_duration},
           occurred_at: occurred_at
         } = connected_event,
         server,
         now,
         caused_by \\ nil
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert connected_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-connected",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" =>
                 if(server.set_up_at, do: server.app_username, else: server.username),
               "ssh_port" => server.ssh_port,
               "connection_duration" => connection_duration,
               "group" => %{
                 "id" => server.group.id,
                 "name" => server.group.name
               },
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" =>
                   if server.owner.group_member do
                     server.owner.group_member.name
                   else
                     nil
                   end,
                 "root" => server.owner.root
               }
             },
             meta: %{},
             initiator: "servers:servers:#{server.id}",
             causation_id: if(caused_by, do: caused_by.id, else: event_id),
             correlation_id: if(caused_by, do: caused_by.correlation_id, else: event_id),
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: connected_event.causation_id,
      correlation_id: connected_event.correlation_id
    }
  end

  defp assert_server_facts_gathered_event!(
         %StoredEvent{id: event_id, occurred_at: occurred_at} = event,
         server,
         facts,
         now,
         caused_by
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-facts-gathered",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "app_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "facts" => facts,
               "group" => %{
                 "id" => server.group.id,
                 "name" => server.group.name
               },
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" =>
                   if server.owner.group_member do
                     server.owner.group_member.name
                   else
                     nil
                   end,
                 "root" => server.owner.root
               }
             },
             meta: %{},
             initiator: "servers:servers:#{server.id}",
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id
    }
  end

  defp assert_ansible_playbook_run_started_event!(
         %StoredEvent{id: event_id, occurred_at: occurred_at} = event,
         run,
         now,
         caused_by
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{run.server_id}",
             version: run.server.version,
             type: "archidep/servers/ansible-playbook-run-started",
             data: %{
               "id" => run.id,
               "playbook" => run.playbook,
               "playbook_path" => run.playbook_path,
               "digest" => Base.encode16(run.digest, case: :lower),
               "git_revision" => run.git_revision,
               "host" => run.host.address |> :inet.ntoa() |> to_string(),
               "port" => run.port,
               "user" => run.user,
               "vars" => run.vars,
               "server" => %{
                 "id" => run.server_id,
                 "name" => run.server.name,
                 "username" => run.server.username
               },
               "group" => %{
                 "id" => run.server.group.id,
                 "name" => run.server.group.name
               },
               "owner" => %{
                 "id" => run.server.owner.id,
                 "username" => run.server.owner.username,
                 "name" =>
                   if run.server.owner.group_member do
                     run.server.owner.group_member.name
                   else
                     nil
                   end,
                 "root" => run.server.owner.root
               }
             },
             meta: %{},
             initiator: "servers:servers:#{run.server_id}",
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id
    }
  end
end
