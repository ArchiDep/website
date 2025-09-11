defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandlePortCheckingTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  setup :verify_on_exit!

  setup_all do
    %{
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "check open ports after the port testing script has run", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_test_ports_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:check_open_ports, check_open_ports_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{}
           }

    fake_task = Task.completed(:fake)

    server_ip_address = server.ip_address.address

    check_open_ports_result =
      check_open_ports_fn.(result, fn ^server_ip_address, [80, 443, 3000, 3001] ->
        fake_task
      end)

    assert check_open_ports_result ==
             %ServerManagerState{result | tasks: %{check_open_ports: fake_task.ref}}

    assert update_tracking_fn.(check_open_ports_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{check_open_ports_result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on successful run", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    result =
      handle_task_result.(
        initial_state,
        fake_test_ports_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:check_open_ports, check_open_ports_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: []
           }

    fake_task = Task.completed(:fake)

    server_ip_address = server.ip_address.address

    check_open_ports_result =
      check_open_ports_fn.(result, fn ^server_ip_address, [80, 443, 3000, 3001] ->
        fake_task
      end)

    assert check_open_ports_result ==
             %ServerManagerState{result | tasks: %{check_open_ports: fake_task.ref}}

    assert update_tracking_fn.(check_open_ports_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{check_open_ports_result | version: result.version + 1}}
  end

  test "handle port testing script failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    port_testing_stderr = Faker.Lorem.sentence()
    port_testing_exit_code = Faker.random_between(1, 255)

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:ok, Faker.Lorem.sentence(), port_testing_stderr, port_testing_exit_code}
        )
      end)

    assert log =~
             "Port testing script exited with code #{port_testing_exit_code} on server #{server.id}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed,
                  {:exit, port_testing_exit_code, port_testing_stderr}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on failure", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    port_testing_stderr = Faker.Lorem.sentence()
    port_testing_exit_code = Faker.random_between(1, 255)

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:ok, Faker.Lorem.sentence(), port_testing_stderr, port_testing_exit_code}
        )
      end)

    assert log =~
             "Port testing script exited with code #{port_testing_exit_code} on server #{server.id}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed,
                  {:exit, port_testing_exit_code, port_testing_stderr}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "handle port testing script error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref}
      )

    port_testing_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:error, port_testing_error}
        )
      end)

    assert log =~
             "Port testing script failed on server #{server.id} because: #{inspect(port_testing_error)}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed, {:error, port_testing_error}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous port testing script problems are dropped on error", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_test_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{test_ports: fake_test_ports_ref},
        problems: [
          ServersFactory.server_port_testing_script_failed_problem(),
          ServersFactory.server_open_ports_check_failed_problem()
        ]
      )

    port_testing_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_test_ports_ref,
          {:error, port_testing_error}
        )
      end)

    assert log =~
             "Port testing script failed on server #{server.id} because: #{inspect(port_testing_error)}"

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_test_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_port_testing_script_failed, {:error, port_testing_error}}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the connection process is done after open ports have been successfully checked", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: nil)

    fake_check_open_ports_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref}
      )

    now = DateTime.utc_now()

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert %{
             server: %{open_ports_checked_at: open_ports_checked_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [ports_checked_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_open_ports_checked_event!(
      ports_checked_event,
      updated_server,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | open_ports_checked_at: open_ports_checked_at,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, open_ports_checked_at, :second), 0, 1

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the server is not updated after open ports have been successfully checked if they had already been checked",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    previous_problems =
      [
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ]
      |> Enum.shuffle()
      |> Enum.drop(Faker.random_between(0, 2))

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: []
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous open ports check problems are dropped after a successful check", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: nil)

    previous_problems =
      Enum.shuffle([
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ])

    fake_check_open_ports_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    now = DateTime.utc_now()

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        :ok
      )

    assert %{
             server: %{open_ports_checked_at: open_ports_checked_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [ports_checked_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_open_ports_checked_event!(
      ports_checked_event,
      updated_server,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | open_ports_checked_at: open_ports_checked_at,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{},
               problems: []
           }

    assert_in_delta DateTime.diff(now, open_ports_checked_at, :second), 0, 1

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "handle open ports check failure", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref}
      )

    port_problems = [{80, Faker.Lorem.sentence()}, {3000, :oops}]

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        {:error, port_problems}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_open_ports_check_failed, port_problems}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "previous open ports check failures are dropped on subsequent failures", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true, open_ports_checked_at: true)

    previous_problems =
      Enum.shuffle([
        ServersFactory.server_open_ports_check_failed_problem(),
        ServersFactory.server_port_testing_script_failed_problem()
      ])

    fake_check_open_ports_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_open_ports: fake_check_open_ports_ref},
        problems: previous_problems
      )

    port_problems = [{80, Faker.Lorem.sentence()}, {3000, :oops}]

    result =
      handle_task_result.(
        initial_state,
        fake_check_open_ports_ref,
        {:error, port_problems}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_open_ports_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_open_ports_check_failed, port_problems}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  defp assert_server_open_ports_checked_event!(
         %StoredEvent{
           id: event_id,
           occurred_at: occurred_at
         } = connected_event,
         server,
         now,
         caused_by
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert connected_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-open-ports-checked",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "app_username" => server.app_username,
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
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: connected_event.causation_id,
      correlation_id: connected_event.correlation_id
    }
  end
end
