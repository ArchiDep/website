defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateGroupUpdatedTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      group_updated: protect({ServerManagerState, :group_updated, 2}, ServerManagerBehaviour)
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

    result = group_updated.(initial_state, updated_class)

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

    assert group_updated.(initial_state, updated_class) == initial_state
  end
end
