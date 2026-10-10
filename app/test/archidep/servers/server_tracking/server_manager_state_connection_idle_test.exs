defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateConnectionIdleTest do
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

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(%{connection_pid: nil}),
        server: server,
        username: "alice",
        version: 24
      )

    %ServerManagerState{} = result = connection_idle.(initial_state, self())

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

    %ServerManagerState{} =
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

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        server: server,
        username: server.username
      )

    now = DateTime.utc_now()
    %ServerManagerState{} = result = connection_idle.(initial_state, self())

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

    %ServerManagerState{} =
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

    %ServerManagerState{} =
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

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        server: server,
        username: "alice",
        version: 42
      )

    %ServerManagerState{} = result = connection_idle.(initial_state, self())

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

  test "a server manager still referencing a previous connection treats a new idle connection as its replacement",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    new_connection_pid = spawn(fn -> :ok end)
    fake_connection_timer_ref = make_ref()

    for {connection_state, connection_timer} <- [
          {ServersFactory.random_not_connected_state(%{connection_pid: self()}), nil},
          {ServersFactory.random_connection_pending_state(), fake_connection_timer_ref},
          {ServersFactory.random_connecting_state(), nil},
          {ServersFactory.random_retry_connecting_state(), nil},
          {ServersFactory.random_reconnecting_state(), nil},
          {ServersFactory.random_connection_failed_state(), nil}
        ] do
      %ServerManagerState{} =
        initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          connection_timer: connection_timer,
          server: server,
          username: server.username
        )

      now = DateTime.utc_now()

      {%ServerManagerState{} = result, log} =
        with_log([format: "[$level] $message\n"], fn ->
          connection_idle.(initial_state, new_connection_pid)
        end)

      assert log_lines_about(log, server) == [
               "[warning] Connection #{inspect(new_connection_pid)} for server #{server.id} became idle while in connection state #{inspect(connection_state)}; considering the previous connection lost"
             ]

      assert_no_stored_events!()

      assert %ServerManagerState{
               connection_state: retry_connecting_state(retrying: %{time: time}),
               actions:
                 [
                   {:monitor, ^new_connection_pid},
                   {:send_message, send_message_fn},
                   {:update_tracking, "servers", update_tracking_fn}
                   | disconnect_actions
                 ] = actions
             } = result

      assert disconnect_actions ==
               Enum.map(List.wrap(connection_timer), &{:cancel_timer, &1}) ++
                 [:notify_server_offline, {:update_tracking, "servers", update_tracking_fn}]

      assert_in_delta DateTime.diff(now, time, :second), 0, 1

      assert result == %ServerManagerState{
               initial_state
               | connection_state:
                   retry_connecting_state(
                     connection_pid: new_connection_pid,
                     retrying: %{
                       retry: 1,
                       backoff: 0,
                       time: time,
                       in_seconds: 5,
                       reason: :disconnected
                     }
                   ),
                 connection_timer: nil,
                 actions: actions
             }

      fake_retry_timer_ref = make_ref()

      %ServerManagerState{} =
        send_message_result =
        send_message_fn.(result, fn :retry_connecting, 5_000 ->
          fake_retry_timer_ref
        end)

      assert send_message_result ==
               %ServerManagerState{result | retry_timer: fake_retry_timer_ref}

      assert update_tracking_fn.(send_message_result) ==
               {real_time_state(server,
                  connection_state: result.connection_state,
                  version: result.version + 1
                ), %ServerManagerState{send_message_result | version: result.version + 1}}
    end
  end

  test "a connected server manager records the previous connection as disconnected when a new connection becomes idle",
       %{connection_idle: connection_idle} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    new_connection_pid = spawn(fn -> :ok end)
    now = DateTime.utc_now()

    {%ServerManagerState{} = result, log} =
      with_log([format: "[$level] $message\n"], fn ->
        connection_idle.(initial_state, new_connection_pid)
      end)

    assert log_lines_about(log, server) == [
             "[warning] Connection #{inspect(new_connection_pid)} for server #{server.id} became idle while in connection state #{inspect(initial_state.connection_state)}; considering the previous connection lost"
           ]

    assert_server_disconnected_event!(server, now, ":connection_replaced")

    assert %ServerManagerState{
             connection_state: retry_connecting_state(retrying: %{time: time}),
             actions:
               [
                 {:monitor, ^new_connection_pid},
                 {:send_message, send_message_fn},
                 {:update_tracking, "servers", update_tracking_fn},
                 :notify_server_offline,
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 retry_connecting_state(
                   connection_pid: new_connection_pid,
                   retrying: %{
                     retry: 1,
                     backoff: 0,
                     time: time,
                     in_seconds: 5,
                     reason: :disconnected
                   }
                 ),
               actions: actions
           }

    fake_retry_timer_ref = make_ref()

    %ServerManagerState{} =
      send_message_result =
      send_message_fn.(result, fn :retry_connecting, 5_000 ->
        fake_retry_timer_ref
      end)

    assert send_message_result ==
             %ServerManagerState{result | retry_timer: fake_retry_timer_ref}

    assert update_tracking_fn.(send_message_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{send_message_result | version: result.version + 1}}
  end

  # Log capture is global, so concurrent tests' logs are interleaved with this
  # test's. Each test builds its own server, so its ID identifies this test's
  # lines.
  defp log_lines_about(log, server),
    do: log |> String.split("\n", trim: true) |> Enum.filter(&String.contains?(&1, server.id))
end
