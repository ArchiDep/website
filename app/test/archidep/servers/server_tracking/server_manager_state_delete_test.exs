defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateDeleteTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Ecto.Query, only: [from: 2]
  import Hammox
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      delete_server: protect({ServerManagerState, :delete_server, 2}, ServerManagerBehaviour)
    }
  end

  test "delete a not connected server", %{delete_server: delete_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_not_connected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    now = DateTime.utc_now()
    result = delete_server.(initial_state, auth)

    assert result == {initial_state, :ok}

    assert_server_deleted!(server, now)
  end

  test "delete a server that is retrying to connect", %{delete_server: delete_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    now = DateTime.utc_now()
    result = delete_server.(initial_state, auth)

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self())
              }, :ok}

    assert_server_deleted!(server, now)
  end

  test "delete a server that is retrying to connect after a given time", %{
    delete_server: delete_server
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
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

    now = DateTime.utc_now()
    result = delete_server.(initial_state, auth)

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self()),
                  actions: [{:cancel_timer, fake_retry_timer_ref}],
                  retry_timer: nil
              }, :ok}

    assert_server_deleted!(server, now)
  end

  test "delete a connected server", %{delete_server: delete_server} do
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

    now = DateTime.utc_now()

    result =
      assert_server_connection_disconnected!(server, fn -> delete_server.(initial_state, auth) end)

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self())
              }, :ok}

    assert_server_deleted!(server, now)
  end

  test "delete server that failed to connect", %{delete_server: delete_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connection_failed_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    now = DateTime.utc_now()

    assert delete_server.(initial_state, auth) ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: self())
              }, :ok}

    assert_server_deleted!(server, now)
  end

  test "delete a disconnected server", %{delete_server: delete_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_disconnected_state(),
        username: server.username,
        server: server
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    now = DateTime.utc_now()

    assert delete_server.(initial_state, auth) ==
             {%ServerManagerState{
                initial_state
                | connection_state: not_connected_state(connection_pid: nil)
              }, :ok}

    assert_server_deleted!(server, now)
  end

  test "cannot delete a server that is busy", %{delete_server: delete_server} do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true
      )

    auth = Factory.build(:authentication, principal_id: server.owner_id, root: false)

    for {busy_state, tasks, ansible_playbook} <- [
          {ServersFactory.random_connected_state(), %{foo: make_ref()}, nil},
          {ServersFactory.random_connected_state(), %{},
           {ServersFactory.build(:ansible_playbook_run, server: server, state: :pending), nil}},
          {ServersFactory.random_connecting_state(), %{}, nil},
          {ServersFactory.random_reconnecting_state(), %{}, nil}
        ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: busy_state,
          username: server.username,
          server: server,
          tasks: tasks,
          ansible_playbook: ansible_playbook
        )

      assert delete_server.(initial_state, auth) == {initial_state, {:error, :server_busy}}
    end

    assert Repo.all(StoredEvent) == []
    assert Repo.exists?(from s in Server, where: s.id == ^server.id)
  end

  defp assert_server_deleted!(server, now) do
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
             stream: "servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-deleted",
             data: %{
               "id" => server.id,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "name" => server.name,
               "ssh_port" => server.ssh_port
             },
             meta: %{},
             initiator: "user-accounts:#{server.owner_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: occurred_at,
             entity: nil
           }

    assert Repo.all(Server) == []
  end
end
