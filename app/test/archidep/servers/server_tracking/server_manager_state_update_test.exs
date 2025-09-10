defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateUpdateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

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
      update_server: protect({ServerManagerState, :update_server, 3}, ServerManagerBehaviour)
    }
  end

  test "update a server", %{update_server: update_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: server.active,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()
    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | server: %Server{
                    server
                    | username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update the application of a server", %{update_server: update_server} do
    server =
      insert_active_server!(
        root: true,
        set_up_at: true,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.app_username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: true)

    new_server_app_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: server.username,
      ssh_port: server.ssh_port,
      active: server.active,
      app_username: new_server_app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()
    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | server: %Server{
                    server
                    | app_username: new_server_app_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_app_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | app_username: new_server_app_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_app_username),
                app_username: new_server_app_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and activate a deactivated server", %{update_server: update_server} do
    server =
      insert_active_server!(
        active: false,
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: true,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()
    result = update_server.(initial_state, auth, data)
    test_pid = self()

    assert {%ServerManagerState{
              connection_state:
                connecting_state(connection_ref: connection_ref, time: connecting_time),
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:monitor, ^test_pid},
                  {:connect, connect_fn},
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert is_reference(connection_ref)
    assert_in_delta DateTime.diff(now, connecting_time, :second), 0, 1
    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state:
                    connecting_state(
                      connection_pid: self(),
                      connection_ref: connection_ref,
                      time: connecting_time,
                      retrying: false
                    ),
                  server: %Server{
                    server
                    | active: true,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: true,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    connect_result = assert_connect_fn!(connect_fn, new_state, new_server_username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                current_job: :connecting,
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{connect_result | version: new_state.version + 1}}
  end

  test "update and deactivate an active connected server", %{update_server: update_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result =
      assert_server_connection_disconnected!(server, fn ->
        update_server.(initial_state, auth, data)
      end)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and deactivate an active server that is retrying to connect", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and deactivate an active server that is retrying to connect after a given time", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    fake_retry_timer_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        username: server.username,
        server: server,
        retry_timer: fake_retry_timer_ref
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:cancel_timer, ^fake_retry_timer_ref},
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions,
                  retry_timer: nil
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and deactivate an active disconnected server", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: nil),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and deactivate an active server that has failed to connect", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connection_failed_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update and deactivate an active server that is not connected", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        server_expected_properties: @no_server_properties
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    new_server_username = Faker.Internet.user_name()

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: new_server_username,
      ssh_port: server.ssh_port,
      active: false,
      app_username: server.app_username,
      expected_properties: Enum.into(@no_server_properties, %{})
    }

    now = DateTime.utc_now()

    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  server: %Server{
                    server
                    | active: false,
                      username: new_server_username,
                      updated_at: updated_at,
                      version: server.version + 1
                  },
                  username: new_server_username,
                  actions: actions
              },
              {:ok,
               %Server{
                 server
                 | active: false,
                   username: new_server_username,
                   updated_at: updated_at,
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "server properties mismatches are re-evaluated when the server is udpated", %{
    update_server: update_server
  } do
    server =
      insert_active_server!(
        root: true,
        set_up_at: nil,
        ssh_port: true,
        class_expected_server_properties: @no_server_properties,
        server_expected_properties: @no_server_properties,
        server_last_known_properties: Keyword.merge(@no_server_properties, cpus: 2)
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: true)

    data = %{
      name: server.name,
      ip_address: server.ip_address.address |> :inet.ntoa() |> to_string(),
      username: server.username,
      ssh_port: server.ssh_port,
      active: server.active,
      app_username: server.app_username,
      expected_properties: @no_server_properties |> Enum.into(%{}) |> Map.put(:cpus, 4)
    }

    now = DateTime.utc_now()
    result = update_server.(initial_state, auth, data)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server}} = result

    assert_in_delta DateTime.diff(now, updated_at, :second), 0, 1

    assert result ==
             {%ServerManagerState{
                initial_state
                | server: %Server{
                    server
                    | updated_at: updated_at,
                      expected_properties: %ServerProperties{
                        server.expected_properties
                        | cpus: 4
                      },
                      version: server.version + 1
                  },
                  actions: actions,
                  problems: [
                    {:server_expected_property_mismatch, :cpus, 4, 2}
                  ]
              },
              {:ok,
               %Server{
                 server
                 | updated_at: updated_at,
                   expected_properties: %ServerProperties{
                     server.expected_properties
                     | cpus: 4
                   },
                   version: server.version + 1
               }}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                problems: new_state.problems,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "cannot update a server with invalid data",
       %{update_server: update_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)
    data = ServersFactory.random_server_data(%{username: ""})

    assert {^initial_state,
            {:error,
             %Changeset{valid?: false, errors: [{:username, {_msg, [validation: :required]}}]}}} =
             update_server.(initial_state, auth, data)
  end

  test "cannot update a connecting server",
       %{update_server: update_server} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connecting_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)
    data = ServersFactory.random_server_data()

    assert update_server.(initial_state, auth, data) == {initial_state, {:error, :server_busy}}
  end

  test "cannot update a reconnecting server",
       %{update_server: update_server} do
    server =
      build_active_server(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_reconnecting_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)
    data = ServersFactory.random_server_data()

    assert update_server.(initial_state, auth, data) == {initial_state, {:error, :server_busy}}
  end
end
