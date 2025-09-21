defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandleConnectionTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ArchiDep.Support.TelemetryTestHelpers
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

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
        ServersFactory.server_authentication_failed_problem(),
        ServersFactory.server_connection_refused_problem(),
        ServersFactory.server_connection_timed_out_problem(),
        ServersFactory.server_key_exchange_failed_problem()
      ])

    other_problems =
      Enum.shuffle([
        ServersFactory.server_ansible_playbook_failed_problem(),
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

  test "a key exchange failure stops the connection process", %{
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
          {:error, :key_exchange_failed}
        )
      end)

    assert log =~
             "Server manager could not connect to server #{server.id} as #{server.username} because key exchange failed"

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
                   reason: :key_exchange_failed
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_key_exchange_failed, nil, server.ssh_host_key_fingerprints}
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

  test "a key exchange failure indicates the offending host key fingerprint if it was previously detected",
       %{
         handle_task_result: handle_task_result
       } do
    server = build_active_server(set_up_at: nil)

    fake_connect_task_ref = make_ref()
    fake_ssh_host_key_fingerprint = ServersFactory.random_ssh_host_key_fingerprint_digest()

    connecting = ServersFactory.random_connecting_state(%{retrying: false})
    connecting_state(connection_pid: connection_pid) = connecting

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connecting,
        server: server,
        username: server.username,
        tasks: %{connect: fake_connect_task_ref},
        problems: [
          ServersFactory.server_authentication_failed_problem(),
          {:server_key_exchange_failed, fake_ssh_host_key_fingerprint,
           server.ssh_host_key_fingerprints}
        ],
        version: 9
      )

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_connect_task_ref,
          {:error, :key_exchange_failed}
        )
      end)

    assert log =~
             "Server manager could not connect to server #{server.id} as #{server.username} because key exchange failed"

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
                   reason: :key_exchange_failed
                 ),
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_key_exchange_failed, fake_ssh_host_key_fingerprint,
                  server.ssh_host_key_fingerprints}
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
            ServersFactory.server_key_exchange_failed_problem(),
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
end
