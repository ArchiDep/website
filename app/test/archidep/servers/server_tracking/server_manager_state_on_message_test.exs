defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateOnMessageTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.SSHFactory

  setup :verify_on_exit!

  setup_all do
    %{
      on_message: protect({ServerManagerState, :on_message, 2}, ServerManagerBehaviour)
    }
  end

  test "receive a message to measure the server's load average", %{on_message: on_message} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    result = on_message.(initial_state, :measure_load_average)

    assert %ServerManagerState{
             actions:
               [
                 {:run_command, run_command_fn}
               ] = actions
           } = result

    assert_no_stored_events!()

    assert result == %ServerManagerState{
             initial_state
             | actions: actions
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: Map.put(result.tasks, :get_load_average, fake_loadavg_task.ref)
           }
  end

  test "receive a message to measure the server's load average when it is not connected", %{
    on_message: on_message
  } do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    for connection_state <- [
          ServersFactory.random_not_connected_state(),
          ServersFactory.random_connecting_state(),
          ServersFactory.random_retry_connecting_state(),
          ServersFactory.random_reconnecting_state(),
          ServersFactory.random_connection_failed_state(),
          ServersFactory.random_disconnected_state()
        ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          username: server.username,
          server: server
        )

      assert {^initial_state, log} =
               with_log(fn -> on_message.(initial_state, :measure_load_average) end)

      assert log =~ "Ignoring :measure_load_average message sent to server #{server.id}"
    end

    assert_no_stored_events!()
  end

  test "receive a message to retry connecting to the server", %{on_message: on_message} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    fake_retry_timer_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        server: server,
        username: server.username,
        retry_timer: fake_retry_timer_ref
      )

    retry_connecting_state(retrying: retrying) = initial_state.connection_state

    now = DateTime.utc_now()
    result = on_message.(initial_state, :retry_connecting)

    assert_no_stored_events!()

    test_pid = self()

    assert %ServerManagerState{
             connection_state:
               connecting_state(connection_ref: connection_ref, time: connecting_time),
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^fake_retry_timer_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)
    assert_in_delta DateTime.diff(now, connecting_time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connecting_state(
                   connection_pid: self(),
                   connection_ref: connection_ref,
                   time: connecting_time,
                   retrying: retrying
                 ),
               actions: actions,
               retry_timer: nil
           }

    connect_result = assert_connect_fn!(connect_fn, result, server.username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "receive a message to indicate that the SSH host key fingerprint of the server the manager is trying to connect to is unknown",
       %{on_message: on_message} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    fake_ssh_host_key_fingerprint = SSHFactory.random_ssh_host_key_fingerprint_digest()

    assert on_message.(initial_state, {:unknown_key_fingerprint, fake_ssh_host_key_fingerprint}) ==
             %ServerManagerState{
               initial_state
               | problems: [
                   {:server_key_exchange_failed, fake_ssh_host_key_fingerprint,
                    server.ssh_host_key_fingerprints}
                 ]
             }

    assert_no_stored_events!()
  end

  test "any previous key exchange problem is replaced when receiving a new unknown key fingerprint message",
       %{on_message: on_message} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server,
        problems: [
          {:server_key_exchange_failed, SSHFactory.random_ssh_host_key_fingerprint_digest(),
           server.ssh_host_key_fingerprints}
        ]
      )

    fake_ssh_host_key_fingerprint = SSHFactory.random_ssh_host_key_fingerprint_digest()

    assert on_message.(initial_state, {:unknown_key_fingerprint, fake_ssh_host_key_fingerprint}) ==
             %ServerManagerState{
               initial_state
               | problems: [
                   {:server_key_exchange_failed, fake_ssh_host_key_fingerprint,
                    server.ssh_host_key_fingerprints}
                 ]
             }

    assert_no_stored_events!()
  end
end
