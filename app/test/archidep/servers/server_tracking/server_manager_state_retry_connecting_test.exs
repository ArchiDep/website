defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateRetryConnectingTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      retry_connecting:
        protect({ServerManagerState, :retry_connecting, 2}, ServerManagerBehaviour)
    }
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

    result = retry_connecting.(initial_state, :automated)

    assert_no_stored_events!()

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

    connect_result = assert_connect_fn!(connect_fn, result, "dave")

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{connect_result | version: 31}}
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

    now = DateTime.utc_now()
    result = retry_connecting.(initial_state, :manual)

    [retried_event] = fetch_new_stored_events()
    retried_event_ref = assert_server_retried_connecting_event!(retried_event, server, now)

    test_pid = self()

    expected_retrying = %{retrying | backoff: 0}

    assert %ServerManagerState{
             connection_state:
               connecting_state(
                 connection_ref: connection_ref,
                 connection_pid: ^test_pid,
                 time: time,
                 retrying: ^expected_retrying
               ),
             actions:
               [
                 {:monitor, ^test_pid},
                 {:connect, connect_fn},
                 {:cancel_timer, ^retry_timer},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert is_reference(connection_ref)
    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connecting_state(
                   connection_ref: connection_ref,
                   connection_pid: test_pid,
                   time: time,
                   retrying: expected_retrying,
                   causation_event: retried_event_ref
                 ),
               actions: actions,
               retry_timer: nil
           }

    connect_result = assert_connect_fn!(connect_fn, result, "dave")

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{connect_result | version: 31}}
  end

  test "retrying to connect to a server following an event resets the backoff delay", %{
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

    fake_event = EventsFactory.build(:event_reference)
    result = retry_connecting.(initial_state, {:event, fake_event})

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

    assert_no_stored_events!()
    assert is_reference(connection_ref)

    assert result == %ServerManagerState{
             initial_state
             | connection_state: connection_state,
               actions: actions,
               retry_timer: nil
           }

    connect_result = assert_connect_fn!(connect_fn, result, "dave")

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{connect_result | version: 31}}
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

    result = retry_connecting.(initial_state, :automated)

    assert_no_stored_events!()

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

    connect_result = assert_connect_fn!(connect_fn, result, "frank")

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: 31
              ), %ServerManagerState{connect_result | version: 31}}
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
               with_log(fn -> retry_connecting.(initial_state, :manual) end)

      assert log =~ "Ignore request to retry connecting"

      assert {^initial_state, log2} =
               with_log(fn -> retry_connecting.(initial_state, :automated) end)

      assert log2 =~ "Ignore request to retry connecting"

      assert {^initial_state, log3} =
               with_log(fn ->
                 retry_connecting.(initial_state, {:event, EventsFactory.build(:event_reference)})
               end)

      assert log3 =~ "Ignore request to retry connecting"
    end

    assert_no_stored_events!()
  end

  defp assert_server_retried_connecting_event!(
         %StoredEvent{
           id: event_id,
           occurred_at: occurred_at
         } = retried_event,
         server,
         now
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert retried_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-retried-connecting",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" =>
                 if(server.set_up_at, do: server.app_username, else: server.username),
               "ssh_port" => server.ssh_port,
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
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: retried_event.causation_id,
      correlation_id: retried_event.correlation_id
    }
  end
end
