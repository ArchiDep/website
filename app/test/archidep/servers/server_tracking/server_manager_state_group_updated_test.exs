defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateGroupUpdatedTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      group_updated: protect({ServerManagerState, :group_updated, 3}, ServerManagerBehaviour)
    }
  end

  test "update server group information in real time", %{group_updated: group_updated} do
    expected_server_properties =
      CourseFactory.build(:expected_server_properties,
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
      )

    class =
      CourseFactory.build(:class,
        active: true,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        last_known_properties: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    updated_class = %Class{
      class
      | name: Faker.Lorem.sentence(),
        start_date: Faker.Date.backward(30),
        version: class.version + 1
    }

    event = EventsFactory.build(:event_reference)

    result = group_updated.(initial_state, updated_class, event)

    assert %ServerManagerState{
             actions: [
               {:update_tracking, "servers", update_tracking_fn}
             ]
           } = result

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | group: %ServerGroup{
                     group
                     | name: updated_class.name,
                       start_date: updated_class.start_date,
                       version: updated_class.version
                   }
               },
               actions: result.actions
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "ignore outdated server group updates", %{group_updated: group_updated} do
    class = CourseFactory.build(:class, active: true, servers_enabled: true)

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        last_known_properties: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    updated_class = %Class{
      class
      | name: Faker.Lorem.sentence(),
        start_date: Faker.Date.backward(30),
        version: class.version - Faker.random_between(1, 10)
    }

    event = EventsFactory.build(:event_reference)

    assert group_updated.(initial_state, updated_class, event) == initial_state
  end

  test "server property mismatches are re-evaluated when a group is updated", %{
    group_updated: group_updated
  } do
    expected_server_properties =
      CourseFactory.build(:expected_server_properties,
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
      )

    class =
      CourseFactory.build(:class,
        active: true,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
          hostname: nil,
          machine_id: nil,
          cpus: 2,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    expected_properties =
      ServersFactory.build(:server_properties,
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
      )

    last_known_properties = ServersFactory.build(:server_properties, cpus: 2)

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        expected_properties: expected_properties,
        last_known_properties: last_known_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    updated_class = %Class{
      class
      | expected_server_properties: %ExpectedServerProperties{
          expected_server_properties
          | cpus: 4
        },
        version: class.version + 1
    }

    event = EventsFactory.build(:event_reference)

    result = group_updated.(initial_state, updated_class, event)

    assert %ServerManagerState{
             actions: [
               {:update_tracking, "servers", update_tracking_fn}
             ]
           } = result

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | group: %ServerGroup{
                     group
                     | expected_server_properties: %ServerProperties{
                         group.expected_server_properties
                         | cpus: 4
                       },
                       version: updated_class.version
                   }
               },
               actions: result.actions,
               problems: [
                 {:server_expected_property_mismatch, :cpus, 4, 2}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "server property mismatches cannot be re-evaluated if the server has no last known properties",
       %{group_updated: group_updated} do
    expected_server_properties =
      CourseFactory.build(:expected_server_properties,
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
      )

    class =
      CourseFactory.build(:class,
        active: true,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
          hostname: nil,
          machine_id: nil,
          cpus: 2,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    expected_properties =
      ServersFactory.build(:server_properties,
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
      )

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        expected_properties: expected_properties,
        last_known_properties: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_expected_property_mismatch_problem(),
          ServersFactory.server_expected_property_mismatch_problem(),
          ServersFactory.server_expected_property_mismatch_problem()
        ]
      )

    updated_class = %Class{
      class
      | expected_server_properties: %ExpectedServerProperties{
          expected_server_properties
          | cpus: 4
        },
        version: class.version + 1
    }

    event = EventsFactory.build(:event_reference)

    result = group_updated.(initial_state, updated_class, event)

    assert %ServerManagerState{
             actions: [
               {:update_tracking, "servers", update_tracking_fn}
             ]
           } = result

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | group: %ServerGroup{
                     group
                     | expected_server_properties: %ServerProperties{
                         group.expected_server_properties
                         | cpus: 4
                       },
                       version: updated_class.version
                   }
               },
               actions: result.actions,
               problems: []
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "a server manager connects to its server when it becomes active following a group update",
       %{group_updated: group_updated} do
    expected_server_properties =
      CourseFactory.build(:expected_server_properties,
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
      )

    class =
      CourseFactory.build(:class,
        active: false,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        last_known_properties: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        server: server,
        username: server.username
      )

    not_connected_state(connection_pid: connection_pid) = initial_state.connection_state

    updated_class = %Class{
      class
      | active: true,
        version: class.version + 1
    }

    event = EventsFactory.build(:event_reference)

    now = DateTime.utc_now()
    result = group_updated.(initial_state, updated_class, event)

    assert %ServerManagerState{
             connection_state:
               connecting_state(connection_ref: connection_ref, time: connecting_time),
             actions: [
               {:monitor, ^connection_pid},
               {:connect, connect_fn},
               {:update_tracking, "servers", update_tracking_fn}
             ]
           } = result

    assert_in_delta DateTime.diff(now, connecting_time, :second), 0, 1

    assert result == %ServerManagerState{
             initial_state
             | connection_state:
                 connecting_state(
                   connection_pid: connection_pid,
                   connection_ref: connection_ref,
                   time: connecting_time,
                   retrying: false,
                   causation_event: event
                 ),
               server: %Server{
                 server
                 | group: %ServerGroup{
                     group
                     | active: true,
                       version: updated_class.version
                   }
               },
               actions: result.actions
           }

    connect_result = assert_connect_fn!(connect_fn, result, server.username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                current_job: :connecting,
                version: result.version + 1
              ), %ServerManagerState{connect_result | version: result.version + 1}}
  end

  test "a server manager shuts down when its server becomes inactive following a group update", %{
    group_updated: group_updated
  } do
    expected_server_properties =
      CourseFactory.build(:expected_server_properties,
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
      )

    class =
      CourseFactory.build(:class,
        active: true,
        servers_enabled: true,
        expected_server_properties: expected_server_properties
      )

    group = %ServerGroup{
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      servers: [],
      expected_server_properties:
        ServersFactory.build(
          :server_properties,
          id: class.expected_server_properties_id,
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
        ),
      expected_server_properties_id: class.expected_server_properties_id,
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }

    server =
      build_active_server(
        group: group,
        root: true,
        set_up_at: nil,
        ssh_port: true,
        last_known_properties: nil
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username
      )

    connected_state(connection_pid: connection_pid) = initial_state.connection_state

    updated_class = %Class{
      class
      | active: false,
        version: class.version + 1
    }

    event = EventsFactory.build(:event_reference)

    result =
      assert_server_connection_disconnected!(server, fn ->
        group_updated.(initial_state, updated_class, event)
      end)

    assert %ServerManagerState{
             actions: [
               {:update_tracking, "servers", update_tracking_fn}
             ]
           } = result

    assert result == %ServerManagerState{
             initial_state
             | connection_state: not_connected_state(connection_pid: connection_pid),
               server: %Server{
                 server
                 | group: %ServerGroup{
                     group
                     | active: false,
                       version: updated_class.version
                   }
               },
               actions: result.actions
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: result.connection_state,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end
end
