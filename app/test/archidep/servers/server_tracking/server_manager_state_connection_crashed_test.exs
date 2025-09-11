defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateConnectionCrashedTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ArchiDep.Support.TelemetryTestHelpers
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
       %{connection_crashed: connection_crashed} = context do
    attach_telemetry_handler!(context, [:archidep, :servers, :tracking, :connection_crashed])

    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    connected_state(time: connected_time) = initial_state.connection_state

    now = DateTime.utc_now()
    crash_reason = Faker.Lorem.sentence()

    result = connection_crashed.(initial_state, self(), crash_reason)

    assert_server_disconnected_event!(server, now, crash_reason)

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

    event_data = assert_telemetry_event!([:archidep, :servers, :tracking, :connection_crashed])
    assert %{measurements: %{duration: connected_duration}} = event_data

    assert_in_delta DateTime.diff(now, connected_time, :millisecond) / 1000,
                    connected_duration,
                    1

    assert event_data == %{
             measurements: %{duration: connected_duration},
             metadata: %{},
             config: nil
           }
  end

  test "handle connection crash when not connected to the server",
       %{connection_crashed: connection_crashed} = context do
    attach_telemetry_handler!(context, [:archidep, :servers, :tracking, :connection_crashed])

    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    for connection_state <- [
          ServersFactory.random_not_connected_state(),
          ServersFactory.random_connecting_state(),
          ServersFactory.random_retry_connecting_state(),
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

      assert_no_stored_events!()

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

      event_data = assert_telemetry_event!([:archidep, :servers, :tracking, :connection_crashed])

      assert event_data == %{
               measurements: %{duration: 0},
               metadata: %{},
               config: nil
             }
    end
  end

  test "pending tasks, timers and connected problems are dropped when the connection crashes",
       %{connection_crashed: connection_crashed} do
    server =
      build_active_server(
        ssh_port: true,
        set_up_at: nil
      )

    fake_gather_facts_task_ref = make_ref()
    fake_loadavg_task_ref = make_ref()
    fake_retry_timer_ref = make_ref()
    fake_loadavg_timer_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server,
        tasks: %{gather_facts: fake_gather_facts_task_ref, load_average: fake_loadavg_task_ref},
        retry_timer: fake_retry_timer_ref,
        load_average_timer: fake_loadavg_timer_ref,
        problems: [
          ServersFactory.server_fact_gathering_failed_problem(),
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    now = DateTime.utc_now()
    crash_reason = :foo

    result = connection_crashed.(initial_state, self(), crash_reason)

    assert_server_disconnected_event!(server, now, ":foo")

    assert %ServerManagerState{
             connection_state: disconnected_state(time: time),
             actions:
               [
                 {:demonitor, ^fake_loadavg_task_ref},
                 {:demonitor, ^fake_gather_facts_task_ref},
                 {:cancel_timer, ^fake_retry_timer_ref},
                 {:cancel_timer, ^fake_loadavg_timer_ref},
                 :notify_server_offline,
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

    assert_no_stored_events!()

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

  defp assert_server_disconnected_event!(server, now, reason) do
    assert [
             %StoredEvent{
               id: event_id,
               data: %{"uptime" => uptime},
               occurred_at: occurred_at
             } = registered_event
           ] =
             Repo.all(
               from e in StoredEvent,
                 order_by: [asc: e.occurred_at]
             )

    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert registered_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-disconnected",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" =>
                 if(server.set_up_at, do: server.app_username, else: server.username),
               "ssh_port" => server.ssh_port,
               "uptime" => uptime,
               "reason" => reason,
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
      causation_id: registered_event.causation_id,
      correlation_id: registered_event.correlation_id
    }
  end
end
