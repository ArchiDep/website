defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateConnectionCrashedTest do
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
      connection_crashed:
        protect({ServerManagerState, :connection_crashed, 3}, ServerManagerBehaviour)
    }
  end

  test "handle connection crash when connected to the server",
       %{connection_crashed: connection_crashed} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    for connection_state <- [
          ServersFactory.random_not_connected_state(),
          ServersFactory.random_connecting_state(),
          ServersFactory.random_retry_connecting_state(),
          ServersFactory.random_connected_state(),
          ServersFactory.random_reconnecting_state(),
          ServersFactory.random_connection_failed_state()
        ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          username: server.username,
          server: server
        )

      now = DateTime.utc_now()
      crash_reason = Faker.Lorem.sentence()

      result = connection_crashed.(initial_state, self(), crash_reason)

      assert %ServerManagerState{
               connection_state: disconnected_state(time: time),
               actions:
                 [
                   :notify_server_offline,
                   {:update_tracking, "servers", update_tracking_fn}
                 ] = actions
             } = result

      assert result == %ServerManagerState{
               initial_state
               | connection_state: disconnected_state(time: time),
                 actions: actions
             }

      assert_in_delta DateTime.diff(now, time, :second), 0, 1

      assert update_tracking_fn.(result) ==
               {real_time_state(server,
                  connection_state: result.connection_state,
                  version: result.version + 1
                ), %ServerManagerState{result | version: result.version + 1}}
    end
  end

  test "pending tasks, timers and connected problems are dropped when the connection crashes",
       %{connection_crashed: connection_crashed} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    fake_loadavg_task_ref = make_ref()
    fake_retry_timer_ref = make_ref()
    fake_loadavg_timer_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server,
        tasks: %{load_average: fake_loadavg_task_ref},
        retry_timer: fake_retry_timer_ref,
        load_average_timer: fake_loadavg_timer_ref,
        problems: [
          ServersFactory.server_fact_gathering_failed_problem(),
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    now = DateTime.utc_now()
    crash_reason = Faker.Lorem.sentence()

    result = connection_crashed.(initial_state, self(), crash_reason)

    assert %ServerManagerState{
             connection_state: disconnected_state(time: time),
             actions:
               [
                 :notify_server_offline,
                 {:cancel_timer, ^fake_retry_timer_ref},
                 {:cancel_timer, ^fake_loadavg_timer_ref},
                 {:demonitor, ^fake_loadavg_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state: disconnected_state(time: time),
               actions: actions,
               tasks: %{},
               retry_timer: nil,
               load_average_timer: nil,
               problems: []
           }

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "handle connection crash when disconnected from the server",
       %{connection_crashed: connection_crashed} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        username: server.username,
        server: server
      )

    now = DateTime.utc_now()
    crash_reason = Faker.Lorem.sentence()

    result = connection_crashed.(initial_state, self(), crash_reason)

    assert %ServerManagerState{
             connection_state: disconnected_state(time: time),
             actions:
               [
                 :notify_server_offline,
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state: disconnected_state(time: time),
               actions: actions
           }

    assert_in_delta DateTime.diff(now, time, :second), 0, 1

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end
end
