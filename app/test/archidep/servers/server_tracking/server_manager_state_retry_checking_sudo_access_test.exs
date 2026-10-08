defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateRetryCheckingSudoAccessTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      retry_checking_sudo_access:
        protect({ServerManagerState, :retry_checking_sudo_access, 1}, ServerManagerBehaviour)
    }
  end

  test "retry checking sudo access with the initial user of a server that is not yet set up", %{
    retry_checking_sudo_access: retry_checking_sudo_access
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          {:server_sudo_access_check_failed, server.username, :timeout}
        ]
      )

    now = DateTime.utc_now()
    assert {%ServerManagerState{} = result, :ok} = retry_checking_sudo_access.(initial_state)

    [retried_event] = fetch_new_stored_events()
    assert_server_retried_checking_sudo_access_event!(retried_event, server, server.username, now)

    assert_sudo_access_check_retried!(result, initial_state, server)
  end

  test "retry checking sudo access with the application user of a server that is set up", %{
    retry_checking_sudo_access: retry_checking_sudo_access
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        problems: [
          {:server_sudo_access_check_failed, server.app_username, :timeout}
        ]
      )

    now = DateTime.utc_now()
    assert {%ServerManagerState{} = result, :ok} = retry_checking_sudo_access.(initial_state)

    [retried_event] = fetch_new_stored_events()

    assert_server_retried_checking_sudo_access_event!(
      retried_event,
      server,
      server.app_username,
      now
    )

    assert_sudo_access_check_retried!(result, initial_state, server)
  end

  test "cannot retry checking sudo access if there is no such problem", %{
    retry_checking_sudo_access: retry_checking_sudo_access
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

    assert retry_checking_sudo_access.(initial_state) == {initial_state, :ok}

    assert_no_stored_events!()
  end

  test "cannot retry checking sudo access if the server is busy running a task", %{
    retry_checking_sudo_access: retry_checking_sudo_access
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_loadavg_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{get_load_average: fake_loadavg_task_ref},
        problems: [ServersFactory.server_sudo_access_check_failed_problem()]
      )

    assert retry_checking_sudo_access.(initial_state) == {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry checking sudo access if the server is busy running an ansible playbook", %{
    retry_checking_sudo_access: retry_checking_sudo_access
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    running_playbook =
      ServersFactory.build(:ansible_playbook_run, server: server, state: :pending)

    fake_cause = EventsFactory.build(:event_reference)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible: {running_playbook, nil, fake_cause},
        problems: [ServersFactory.server_sudo_access_check_failed_problem()]
      )

    assert retry_checking_sudo_access.(initial_state) == {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry checking sudo access if the server is not connected", %{
    retry_checking_sudo_access: retry_checking_sudo_access
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

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
          problems: [ServersFactory.server_sudo_access_check_failed_problem()]
        )

      assert retry_checking_sudo_access.(initial_state) ==
               {initial_state, {:error, :server_not_connected}}
    end

    assert_no_stored_events!()
  end

  defp assert_sudo_access_check_retried!(
         %ServerManagerState{} = result,
         %ServerManagerState{} = initial_state,
         server
       ) do
    assert %{
             actions:
               [
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{initial_state | problems: [], actions: actions}

    fake_task = Task.completed(:fake)

    %ServerManagerState{} =
      run_command_result =
      run_command_fn.(result, fn "sudo -n ls", 20_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{check_access: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: initial_state.username),
                current_job: :checking_access,
                problems: [],
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  defp assert_server_retried_checking_sudo_access_event!(
         %StoredEvent{
           id: event_id,
           occurred_at: occurred_at
         } = retried_event,
         server,
         ssh_username,
         now
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert retried_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             schema_version: 1,
             type: "archidep/servers/server-retried-checking-sudo-access",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" => ssh_username,
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
  end
end
