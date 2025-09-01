defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateOnMessageTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

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

    result = on_message.(initial_state, :retry_connecting)

    test_pid = self()

    assert %ServerManagerState{
             connection_state: connecting_state(connection_ref: connection_ref),
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^fake_retry_timer_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connecting_state(
                   connection_pid: self(),
                   connection_ref: connection_ref,
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
end
