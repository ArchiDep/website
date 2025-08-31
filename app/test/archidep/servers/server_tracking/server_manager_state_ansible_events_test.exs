defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateAnsibleEventsTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID
  alias Phoenix.PubSub
  alias Phoenix.Token

  @pubsub ArchiDep.PubSub

  @no_server_properties [
    hostname: nil,
    machine_id: nil,
    cpus: nil,
    cores: nil,
    vcpus: nil,
    memory: nil,
    swap: nil,
    system: nil,
    architecture: nil,
    os_family: nil,
    distribution: nil,
    distribution_release: nil,
    distribution_version: nil
  ]

  setup :verify_on_exit!

  setup_all do
    %{
      ansible_playbook_completed:
        protect({ServerManagerState, :ansible_playbook_completed, 2}, ServerManagerBehaviour),
      ansible_playbook_event:
        protect({ServerManagerState, :ansible_playbook_event, 3}, ServerManagerBehaviour),
      connection_idle: protect({ServerManagerState, :connection_idle, 2}, ServerManagerBehaviour),
      init: protect({ServerManagerState, :init, 2}, ServerManagerBehaviour),
      group_updated: protect({ServerManagerState, :group_updated, 2}, ServerManagerBehaviour),
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour),
      online?: protect({ServerManagerState, :online?, 1}, ServerManagerBehaviour),
      retry_ansible_playbook:
        protect({ServerManagerState, :retry_ansible_playbook, 2}, ServerManagerBehaviour),
      retry_checking_open_ports:
        protect({ServerManagerState, :retry_checking_open_ports, 1}, ServerManagerBehaviour),
      retry_connecting:
        protect({ServerManagerState, :retry_connecting, 2}, ServerManagerBehaviour)
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

  defp assert_connect_fn!(connect_fn, state, username) do
    fake_task = Task.completed(:fake)

    expected_host = state.server.ip_address.address
    expected_port = state.server.ssh_port || 22
    expected_opts = [silently_accept_hosts: true]

    result =
      connect_fn.(state, fn ^expected_host, ^expected_port, ^username, ^expected_opts ->
        fake_task
      end)

    assert result == %ServerManagerState{state | tasks: %{connect: fake_task.ref}}

    result
  end

  defp build_active_server(opts! \\ []) do
    {group, opts!} =
      Keyword.pop_lazy(opts!, :group, fn ->
        ServersFactory.build(:server_group, active: true, servers_enabled: true)
      end)

    {root, opts!} = Keyword.pop_lazy(opts!, :root, &FactoryHelpers.bool/0)

    member =
      if root do
        nil
      else
        ServersFactory.build(:server_group_member, active: true, group: group)
      end

    owner = ServersFactory.build(:server_owner, active: true, root: root, group_member: member)

    ServersFactory.build(
      :server,
      Keyword.merge([active: true, group: group, group_id: group.id, owner: owner], opts!)
    )
  end

  defp insert_active_server!(opts!) do
    class_id = UUID.generate()

    {class_expected_server_properties, opts!} =
      Keyword.pop(opts!, :class_expected_server_properties, [])

    expected_server_properties =
      CourseFactory.insert(
        :expected_server_properties,
        Keyword.merge(class_expected_server_properties, id: class_id)
      )

    class =
      CourseFactory.insert(:class,
        id: class_id,
        active: true,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    {:ok, group} = ServerGroup.fetch_server_group(class.id)

    root = FactoryHelpers.bool()

    member =
      if root do
        nil
      else
        user_account = AccountsFactory.insert(:user_account)
        {:ok, user} = User.fetch_user(user_account.id)

        student =
          CourseFactory.insert(:student,
            active: true,
            class: class,
            class_id: group.id,
            user: user,
            user_id: user.id
          )

        student.id |> ServerGroupMember.fetch_server_group_member() |> unpair_ok()
      end

    owner =
      if member do
        Repo.update_all(UserAccount, set: [preregistered_user_id: member.id])
        member.owner_id |> ServerOwner.fetch_server_owner() |> unpair_ok()
      else
        user_account = AccountsFactory.insert(:user_account, active: true, root: true)
        user_account.id |> ServerOwner.fetch_server_owner() |> unpair_ok()
      end

    id = UUID.generate()

    {server_expected_properties, opts!} =
      Keyword.pop(opts!, :server_expected_properties, [])

    expected_properties =
      ServersFactory.insert(:server_properties, Keyword.merge(server_expected_properties, id: id))

    {server_last_known_properties, opts!} = Keyword.pop(opts!, :server_last_known_properties, [])

    last_known_properties =
      if server_last_known_properties == [] do
        nil
      else
        ServersFactory.insert(
          :server_properties,
          Keyword.merge(server_last_known_properties, id: UUID.generate())
        )
      end

    ServersFactory.insert(
      :server,
      Keyword.merge(
        [
          id: id,
          active: true,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id,
          expected_properties: expected_properties,
          last_known_properties: last_known_properties
        ],
        opts!
      )
    )

    id |> Server.fetch_server() |> unpair_ok()
  end

  defp generate_server!(attrs \\ []) do
    user_account = AccountsFactory.insert(:user_account)
    course = CourseFactory.insert(:class, servers_enabled: true)

    incomplete_server =
      ServersFactory.insert(
        :server,
        Keyword.merge(
          [active: true, owner_id: user_account.id, group_id: course.id, set_up_at: nil],
          attrs
        )
      )

    fetch_server!(incomplete_server.id)
  end

  defp track_server_action(server, state), do: {:track, "servers", server.id, state}

  defp real_time_state(server, attrs! \\ []) do
    {connection_state, attrs!} =
      Keyword.pop_lazy(attrs!, :connection_state, fn -> not_connected_state() end)

    {conn_params, attrs!} = Keyword.pop_lazy(attrs!, :conn_params, fn -> conn_params(server) end)
    {current_job, attrs!} = Keyword.pop(attrs!, :current_job, nil)
    {problems, attrs!} = Keyword.pop(attrs!, :problems, [])
    {set_up_at, attrs!} = Keyword.pop_lazy(attrs!, :set_up_at, fn -> server.set_up_at end)
    {version, attrs!} = Keyword.pop(attrs!, :version, 0)

    [] = Keyword.keys(attrs!)

    %ServerRealTimeState{
      connection_state: connection_state,
      name: server.name,
      conn_params: conn_params,
      username: server.username,
      app_username: server.app_username,
      current_job: current_job,
      problems: problems,
      set_up_at: set_up_at,
      version: version
    }
  end

  defp conn_params(server, attrs! \\ []) do
    {username, attrs!} = Keyword.pop(attrs!, :username, server.username)

    [] = Keyword.keys(attrs!)

    {server.ip_address.address, server.ssh_port || 22, username}
  end

  defp fetch_server!(id),
    do:
      Repo.one!(
        from s in Server,
          join: o in assoc(s, :owner),
          left_join: ogm in assoc(o, :group_member),
          left_join: ogmg in assoc(ogm, :group),
          join: g in assoc(s, :group),
          join: gesp in assoc(g, :expected_server_properties),
          join: ep in assoc(s, :expected_properties),
          left_join: lkp in assoc(s, :last_known_properties),
          where: s.id == ^id,
          preload: [
            group: {g, expected_server_properties: gesp},
            expected_properties: ep,
            last_known_properties: lkp,
            owner: {o, group_member: {ogm, group: ogmg}}
          ]
      )

  defp ssh_public_key,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:ssh_public_key)
end
