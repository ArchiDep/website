defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateAnsibleEventsTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task}
      )

    event_name = Faker.Lorem.word()

    result =
      ansible_playbook_event.(
        initial_state,
        playbook_run.id,
        event_name
      )

    assert %{
             actions:
               [
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | ansible_playbook: {playbook_run, event_name},
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task}
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

    assert %{
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task},
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

    assert %{
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task},
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

    assert %{
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_loadavg_task_ref},
                 {:connect, connect_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task},
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

    assert %{
             server: %Server{set_up_at: %DateTime{} = set_up_at} = updated_server,
             actions:
               [
                 {:connect, connect_fn},
                 {:cancel_timer, ^fake_loadavg_timer_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_in_delta DateTime.diff(now, set_up_at, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 reconnecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref
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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        ansible_playbook: {playbook_run, previous_task}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        ansible_playbook: {playbook_run, previous_task}
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

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

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        ansible_playbook: {playbook_run, previous_task},
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ]
      )

    result =
      ansible_playbook_completed.(
        initial_state,
        playbook_run.id
      )

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
end
