defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateUpdateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  setup :verify_on_exit!

  setup_all do
    %{
      update_server: protect({ServerManagerState, :update_server, 3}, ServerManagerBehaviour)
    }
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
    data = ServersFactory.random_update_server_data(%{username: ""})

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
    data = ServersFactory.random_update_server_data()

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
    data = ServersFactory.random_update_server_data()

    assert update_server.(initial_state, auth, data) == {initial_state, {:error, :server_busy}}
  end
end
