defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateConnectionIdleTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      connection_idle: protect({ServerManagerState, :connection_idle, 2}, ServerManagerBehaviour)
    }
  end

  test "a not connected server manager for an active server schedules a connection when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: 2222,
        username: "alice",
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(%{connection_pid: nil}),
        server: server,
        username: "alice",
        version: 24
      )

    result = connection_idle.(initial_state, self())

    assert_no_stored_events!()

    test_pid = self()

    assert %ServerManagerState{
             actions:
               [
                 {:send_message, send_message_fn},
                 {:monitor, ^test_pid},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_pending_state(connection_pid: test_pid),
               actions: actions
           }

    fake_timer_ref = make_ref()

    send_message_result =
      send_message_fn.(result, fn :connect, _connect_delay ->
        fake_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | connection_timer: fake_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: nil,
                version: 25
              ), %ServerManagerState{send_message_result | version: 25}}
  end

  test "a disconnected server manager for an active server schedules a connection retry when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        server: server,
        username: server.username
      )

    now = DateTime.utc_now()
    result = connection_idle.(initial_state, self())

    assert_no_stored_events!()

    test_pid = self()

    assert %ServerManagerState{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:monitor, ^test_pid},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: test_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :disconnected
                   }
                 ),
               username: server.username,
               actions: actions
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
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
  end

  test "a not connected server manager for an inactive server remains not connected when the connection becomes idle",
       %{connection_idle: connection_idle} do
    server = ServersFactory.build(:server, active: false, username: "alice", set_up_at: nil)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(%{connection_pid: nil}),
        server: server,
        username: "alice",
        version: 42
      )

    result = connection_idle.(initial_state, self())

    assert_no_stored_events!()

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

    assert_no_stored_events!()

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
end
