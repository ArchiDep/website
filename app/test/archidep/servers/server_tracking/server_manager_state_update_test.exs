defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateUpdateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
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

    updated_event =
      assert_server_updated_event!(%Server{server | username: new_server_username}, now)

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

    assert update_tracking_fn.(new_state) ==
             {real_time_state(server,
                connection_state: new_state.connection_state,
                conn_params: conn_params(server, username: new_server_username),
                username: new_server_username,
                version: new_state.version + 1
              ), %ServerManagerState{new_state | version: new_state.version + 1}}
  end

  test "update the application username of a server", %{update_server: update_server} do
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

    updated_event =
      assert_server_updated_event!(
        %Server{server | app_username: new_server_app_username, active: true},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: true},
        now
      )

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
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
                      retrying: false,
                      causation_event: updated_event
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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:cancel_timer, ^fake_retry_timer_ref},
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | username: new_server_username, active: false},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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

    updated_event =
      assert_server_updated_event!(
        %Server{server | expected_properties: %{server.expected_properties | cpus: 4}},
        now
      )

    assert {%ServerManagerState{
              server: %Server{updated_at: updated_at} = updated_server,
              actions:
                [
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, {:ok, updated_server, ^updated_event}} = result

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
               }, updated_event}}

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
    data = ServersFactory.random_server_data(username: "")

    assert {^initial_state,
            {:error,
             %Changeset{valid?: false, errors: [{:username, {_msg, [validation: :required]}}]}}} =
             update_server.(initial_state, auth, data)

    assert_no_stored_events!()
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

    assert_no_stored_events!()
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

    assert_no_stored_events!()
  end

  defp assert_server_updated_event!(server, now) do
    assert [
             %StoredEvent{
               id: event_id,
               occurred_at: occurred_at
             } = registered_event
           ] = Repo.all(from e in StoredEvent, order_by: [asc: e.occurred_at])

    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert registered_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version + 1,
             type: "archidep/servers/server-updated",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "app_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "active" => server.active,
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
               },
               "expected_properties" => %{
                 "hostname" => server.expected_properties.hostname,
                 "machine_id" => server.expected_properties.machine_id,
                 "cpus" => server.expected_properties.cpus,
                 "cores" => server.expected_properties.cores,
                 "vcpus" => server.expected_properties.vcpus,
                 "memory" => server.expected_properties.memory,
                 "swap" => server.expected_properties.swap,
                 "system" => server.expected_properties.system,
                 "architecture" => server.expected_properties.architecture,
                 "os_family" => server.expected_properties.os_family,
                 "distribution" => server.expected_properties.distribution,
                 "distribution_release" => server.expected_properties.distribution_release,
                 "distribution_version" => server.expected_properties.distribution_version
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{server.owner_id}",
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
