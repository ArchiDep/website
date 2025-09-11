defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateAnsibleEventsTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID
  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  setup :verify_on_exit!

  setup_all do
    %{
      ansible_playbook_completed:
        protect({ServerManagerState, :ansible_playbook_completed, 2}, ServerManagerBehaviour),
      ansible_playbook_event:
        protect({ServerManagerState, :ansible_playbook_event, 3}, ServerManagerBehaviour)
    }
  end

  test "keep track of executing ansible playbook events",
       %{
         ansible_playbook_event: ansible_playbook_event
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.build(:ansible_playbook_run,
        server: server,
        state: :pending
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_cause}
      )

    event_name = Faker.Lorem.word()

    result =
      ansible_playbook_event.(
        initial_state,
        playbook_run.id,
        event_name
      )

    assert_no_stored_events!([fake_cause])

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: {playbook_run, event_name, fake_cause},
               actions: actions
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                current_job:
                  {:running_playbook, playbook_run.playbook, playbook_run.id, event_name},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "ignore ansible playbook events if there is no playbook running",
       %{
         ansible_playbook_event: ansible_playbook_event
       } do
    server = build_active_server()

    for state <-
          [
            ServersFactory.random_connected_state(),
            ServersFactory.random_not_connected_state(),
            ServersFactory.random_connecting_state(),
            ServersFactory.random_retry_connecting_state(),
            ServersFactory.random_reconnecting_state(),
            ServersFactory.random_connection_failed_state(),
            ServersFactory.random_disconnected_state()
          ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: state,
          server: server,
          ansible_playbook: nil
        )

      playbook_run_id = UUID.generate()
      event_name = Faker.Lorem.word()

      {^initial_state, log} =
        with_log(fn ->
          ansible_playbook_event.(
            initial_state,
            playbook_run_id,
            event_name
          )
        end)

      assert log =~
               "Ignoring Ansible playbook event for server #{server.id} because no playbook is running"
    end

    assert_no_stored_events!()
  end

  test "mark a server as set up if the setup playbook completes successfully",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_connection_event}
      )

    connected_state(connection_pid: connection_pid, connection_ref: connection_ref) =
      initial_state.connection_state

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    {_setup_event, reconnecting_event} =
      assert_server_set_up_and_reconnection_events!(server, now, fake_connection_event)

    assert %{
             connection_state: reconnecting_state(time: reconnecting_time),
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, reconnecting_time, :second), 0, 1
    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref,
                   time: reconnecting_time,
                   causation_event: reconnecting_event
                 ),
               server: %Server{server | set_up_at: set_up_at, version: server.version + 1},
               username: server.app_username,
               ansible_playbook: nil,
               actions: actions
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    connect_result = assert_connect_fn!(connect_fn, result, server.app_username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                set_up_at: set_up_at,
                current_job: :reconnecting,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "previous setup playbook problems are dropped when the setup playbook completes successfully",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()
    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_cause},
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ]
      )

    connected_state(connection_pid: connection_pid, connection_ref: connection_ref) =
      initial_state.connection_state

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    {_setup_event, reconnecting_event} =
      assert_server_set_up_and_reconnection_events!(server, now, fake_cause, [
        fake_connection_event
      ])

    assert %{
             connection_state: reconnecting_state(time: reconnecting_time),
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, reconnecting_time, :second), 0, 1
    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref,
                   time: reconnecting_time,
                   causation_event: reconnecting_event
                 ),
               server: %Server{server | set_up_at: set_up_at, version: server.version + 1},
               username: server.app_username,
               ansible_playbook: nil,
               actions: actions,
               problems: []
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    connect_result = assert_connect_fn!(connect_fn, result, server.app_username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                set_up_at: set_up_at,
                current_job: :reconnecting,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "any pending load average result is dropped before reconnection",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_loadavg_task_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_connection_event},
        tasks: %{get_load_average: fake_loadavg_task_ref}
      )

    connected_state(connection_pid: connection_pid, connection_ref: connection_ref) =
      initial_state.connection_state

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    {_setup_event, reconnecting_event} =
      assert_server_set_up_and_reconnection_events!(server, now, fake_connection_event)

    assert %{
             connection_state: reconnecting_state(time: reconnecting_time),
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_loadavg_task_ref},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, reconnecting_time, :second), 0, 1
    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref,
                   time: reconnecting_time,
                   causation_event: reconnecting_event
                 ),
               server: %Server{server | set_up_at: set_up_at, version: server.version + 1},
               username: server.app_username,
               ansible_playbook: nil,
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    connect_result = assert_connect_fn!(connect_fn, result, server.app_username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                set_up_at: set_up_at,
                current_job: :reconnecting,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "any pending load average timer is canceled before reconnection",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_loadavg_timer_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_connection_event},
        load_average_timer: fake_loadavg_timer_ref
      )

    connected_state(connection_pid: connection_pid, connection_ref: connection_ref) =
      initial_state.connection_state

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    {_setup_event, reconnecting_event} =
      assert_server_set_up_and_reconnection_events!(server, now, fake_connection_event)

    assert %{
             connection_state: reconnecting_state(time: reconnection_time),
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:cancel_timer, ^fake_loadavg_timer_ref},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, reconnection_time, :second), 0, 1
    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref,
                   time: reconnection_time,
                   causation_event: reconnecting_event
                 ),
               server: %Server{server | set_up_at: set_up_at, version: server.version + 1},
               username: server.app_username,
               ansible_playbook: nil,
               actions: actions,
               load_average_timer: nil
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    connect_result = assert_connect_fn!(connect_fn, result, server.app_username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                set_up_at: set_up_at,
                current_job: :reconnecting,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "the application user connection process is complete after the setup playbook completes successfully",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        ansible_playbook: {playbook_run, previous_task, fake_cause}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    assert_no_stored_events!([fake_cause])

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: nil,
               actions: actions
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "a setup playbook error interrupts the setup process for the normal user",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :failed,
        stats_changed: 0,
        stats_failures: 1,
        stats_ignored: 2,
        stats_ok: 3,
        stats_rescued: 4,
        stats_skipped: 5,
        stats_unreachable: 6
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_cause}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    assert_no_stored_events!([fake_cause])

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: nil,
               actions: actions,
               problems: [
                 {:server_ansible_playbook_failed, "setup", :failed,
                  %{
                    changed: 0,
                    failures: 1,
                    ignored: 2,
                    ok: 3,
                    rescued: 4,
                    skipped: 5,
                    unreachable: 6
                  }}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "a setup playbook error interrupts the connection process for the application user",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :failed,
        stats_changed: 0,
        stats_failures: 1,
        stats_ignored: 2,
        stats_ok: 3,
        stats_rescued: 4,
        stats_skipped: 5,
        stats_unreachable: 6
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        ansible_playbook: {playbook_run, previous_task, fake_cause}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    assert_no_stored_events!([fake_cause])

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: nil,
               actions: actions,
               problems: [
                 {:server_ansible_playbook_failed, "setup", :failed,
                  %{
                    changed: 0,
                    failures: 1,
                    ignored: 2,
                    ok: 3,
                    rescued: 4,
                    skipped: 5,
                    unreachable: 6
                  }}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "completed ansible playbooks are ignored when the server is not connected",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :failed,
        stats_changed: 0,
        stats_failures: 1,
        stats_ignored: 2,
        stats_ok: 3,
        stats_rescued: 4,
        stats_skipped: 5,
        stats_unreachable: 6
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        server: server,
        username: server.app_username
      )

    {result, log} =
      with_log(fn ->
        ansible_playbook_completed.(
          initial_state,
          playbook_run.id
        )
      end)

    assert_no_stored_events!()

    assert log =~
             "Ignoring completed Ansible playbook run #{playbook_run.id} for server #{server.id}"

    assert result == initial_state
  end

  test "previous setup playbook problems are dropped on subsequent failures",
       %{
         ansible_playbook_completed: ansible_playbook_completed
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    playbook_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :failed,
        stats_changed: 0,
        stats_failures: 1,
        stats_ignored: 2,
        stats_ok: 3,
        stats_rescued: 4,
        stats_skipped: 5,
        stats_unreachable: 6
      )

    previous_task =
      if FactoryHelpers.bool() do
        Faker.Lorem.word()
      else
        nil
      end

    fake_cause = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task, fake_cause},
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ]
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

    assert_no_stored_events!([fake_cause])

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: nil,
               actions: actions,
               problems: [
                 {:server_ansible_playbook_failed, "setup", :failed,
                  %{
                    changed: 0,
                    failures: 1,
                    ignored: 2,
                    ok: 3,
                    rescued: 4,
                    skipped: 5,
                    unreachable: 6
                  }}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  defp assert_server_set_up_and_reconnection_events!(server, now, caused_by, except \\ []) do
    caused_by_id = caused_by.id
    ids_to_exclude = [caused_by_id | Enum.map(except, & &1.id)]

    assert [
             %StoredEvent{
               id: setup_event_id,
               occurred_at: setup_occurred_at
             } = setup_event,
             %StoredEvent{
               id: reconnecting_event_id,
               occurred_at: reconnecting_occurred_at
             } = reconnecting_event
           ] =
             Repo.all(
               from e in StoredEvent,
                 where: e.id not in ^ids_to_exclude,
                 order_by: [asc: e.occurred_at]
             )

    assert_in_delta DateTime.diff(now, setup_occurred_at, :second), 0, 1
    assert_in_delta DateTime.diff(now, reconnecting_occurred_at, :second), 0, 1

    assert setup_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: setup_event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version + 1,
             type: "archidep/servers/server-set-up",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "app_username" => server.app_username,
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
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: setup_occurred_at,
             entity: nil
           }

    assert reconnecting_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: reconnecting_event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version + 1,
             type: "archidep/servers/server-reconnecting",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" => server.app_username,
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
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: reconnecting_occurred_at,
             entity: nil
           }

    {
      %EventReference{
        id: setup_event_id,
        causation_id: setup_event.causation_id,
        correlation_id: setup_event.correlation_id
      },
      %EventReference{
        id: reconnecting_event_id,
        causation_id: reconnecting_event.causation_id,
        correlation_id: reconnecting_event.correlation_id
      }
    }
  end
end
