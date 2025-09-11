defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateRetryConnectingTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

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

    result = retry_connecting.(initial_state, :manual)

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

    cause = ServersFactory.random_retry_connecting_cause()
    result = retry_connecting.(initial_state, cause)

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
               with_log(fn -> retry_connecting.(initial_state, {:event, UUID.generate()}) end)

      assert log3 =~ "Ignore request to retry connecting"
    end
  end
end
