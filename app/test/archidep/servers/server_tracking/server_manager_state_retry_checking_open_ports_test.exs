defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateRetryCheckingOpenPortsTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      retry_checking_open_ports:
        protect({ServerManagerState, :retry_checking_open_ports, 1}, ServerManagerBehaviour)
    }
  end

  test "retry checking open ports after a port testing script failure", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_port_testing_script_failed_problem()
        ]
      )

    now = DateTime.utc_now()
    assert {result, :ok} = retry_checking_open_ports.(initial_state)

    [retried_event] = fetch_new_stored_events()

    retried_event_ref =
      assert_server_retried_checking_open_ports_event!(retried_event, server, now)

    assert %{
             actions:
               [
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(initial_state.connection_state, retry_event: retried_event_ref),
               actions: actions
           }

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :checking_open_ports,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "retry checking open ports after a failed open ports check", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    now = DateTime.utc_now()
    assert {result, :ok} = retry_checking_open_ports.(initial_state)

    [retried_event] = fetch_new_stored_events()

    retried_event_ref =
      assert_server_retried_checking_open_ports_event!(retried_event, server, now)

    assert %{
             actions:
               [
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connected_state(initial_state.connection_state, retry_event: retried_event_ref),
               actions: actions
           }

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :checking_open_ports,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "cannot retry checking open ports if there is no such problem", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    assert retry_checking_open_ports.(initial_state) == {initial_state, :ok}

    assert_no_stored_events!()
  end

  test "cannot retry checking open ports if the server is busy running a task", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    port_checking_problems =
      [
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ]
      |> Enum.shuffle()
      |> Enum.drop(Faker.random_between(0, 1))

    fake_loadavg_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_loadavg_task_ref},
        problems: port_checking_problems
      )

    assert retry_checking_open_ports.(initial_state) == {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry checking open ports if the server is busy running an ansible playbook", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    port_checking_problems =
      [
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ]
      |> Enum.shuffle()
      |> Enum.drop(Faker.random_between(0, 1))

    running_playbook =
      ServersFactory.build(:ansible_playbook_run, server: server, state: :pending)

    fake_cause = EventsFactory.build(:event_reference)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible: {running_playbook, nil, fake_cause},
        problems: port_checking_problems
      )

    assert retry_checking_open_ports.(initial_state) == {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry checking open ports if the server is not connected", %{
    retry_checking_open_ports: retry_checking_open_ports
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    port_checking_problems =
      [
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ]
      |> Enum.shuffle()
      |> Enum.drop(Faker.random_between(0, 1))

    for connection_state <-
          [
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
          server: server,
          username: server.username,
          problems: port_checking_problems
        )

      assert retry_checking_open_ports.(initial_state) ==
               {initial_state, {:error, :server_not_connected}}
    end

    assert_no_stored_events!()
  end

  defp assert_server_retried_checking_open_ports_event!(
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
             type: "archidep/servers/server-retried-checking-open-ports",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" =>
                 if(server.set_up_at, do: server.app_username, else: server.username),
               "ssh_port" => server.ssh_port,
               "ports" => [80, 443, 3000, 3001],
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
