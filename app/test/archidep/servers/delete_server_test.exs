defmodule ArchiDep.Servers.DeleteServerTest do
  # Tests the database-mutating arity `delete_server(auth, %Server{})` that
  # removes a server and its owned rows; the binary-id arity that serializes the
  # deletion through the server-tracking processes is tested separately.
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.UseCases.DeleteServer
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersTestHelpers

  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2023-09-15 09:42:17.000000Z]

  @affected_tables [Server, ServerProperties, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  # Deleting an active vs. an inactive server differs only in whether the
  # owner's active-server count is decremented, so each gets its own test.

  test "deletes an inactive server" do
    {auth, owner_id, group_id} = root_owner_and_group()
    set_owner_counts(owner_id, server_count: 1, active_server_count: 0)

    server =
      ServersTestHelpers.insert_server(owner_id, group_id,
        name: "Doomed",
        ssh_port: 2222,
        active: false
      )

    previous_counts = count_rows(@affected_tables)
    :ok = subscribe(server)

    assert DeleteServer.delete_server(auth, server) == :ok

    server
    |> assert_server_deleted_event(auth)
    |> assert_server_and_properties_gone()
    |> assert_server_deleted_broadcast()

    assert_row_count_diff(previous_counts, %{
      Server => -1,
      ServerProperties => -1,
      StoredEvent => 1
    })

    # Deleting an inactive server leaves the active-server count untouched.
    assert_owner_counts(owner_id, server_count: 0, active_server_count: 0)
  end

  test "deletes an active server, decrementing the active-server count" do
    {auth, owner_id, group_id} = root_owner_and_group()
    set_owner_counts(owner_id, server_count: 1, active_server_count: 1)

    server =
      ServersTestHelpers.insert_server(owner_id, group_id,
        name: "Doomed",
        ssh_port: 2222,
        active: true
      )

    previous_counts = count_rows(@affected_tables)
    :ok = subscribe(server)

    assert DeleteServer.delete_server(auth, server) == :ok

    server
    |> assert_server_deleted_event(auth)
    |> assert_server_and_properties_gone()
    |> assert_server_deleted_broadcast()

    assert_row_count_diff(previous_counts, %{
      Server => -1,
      ServerProperties => -1,
      StoredEvent => 1
    })

    assert_owner_counts(owner_id, server_count: 0, active_server_count: 0)
  end

  defp root_owner_and_group do
    {auth, account} = ServersTestHelpers.register_root(@past)
    group = CourseFactory.insert(:class, now: @past)
    {auth, account.id, group.id}
  end

  # The deletion event is intentionally minimal — only the deleted server's
  # identity — so there is no row to reconstruct from it; it is asserted whole
  # and the rows are asserted gone separately.
  defp assert_server_deleted_event(%Server{id: id, version: version} = server, auth) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: version,
             type: "archidep/servers/server-deleted",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
               "ssh_port" => server.ssh_port,
               "group" => %{"id" => server.group.id, "name" => server.group.name},
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" => owner_name(server.owner),
                 "root" => server.owner.root
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    server
  end

  defp assert_server_and_properties_gone(
         %Server{id: id, expected_properties_id: props_id} = server
       ) do
    refute Repo.exists?(from s in Server, where: s.id == ^id)
    refute Repo.exists?(from p in ServerProperties, where: p.id == ^props_id)
    server
  end

  defp assert_server_deleted_broadcast(%Server{id: id} = server) do
    assert_receive {:server_deleted, %Server{id: ^id} = on_server}
    assert_receive {:server_deleted, %Server{id: ^id} = on_group}
    assert_receive {:server_deleted, %Server{id: ^id} = on_owner}

    assert on_server == server
    assert on_group == server
    assert on_owner == server

    refute_received {:server_deleted, %Server{id: ^id}}
  end

  defp assert_owner_counts(owner_id, server_count: server_count, active_server_count: active) do
    {:ok, owner} = ServerOwner.fetch_server_owner(owner_id)
    assert owner.server_count == server_count
    assert owner.active_server_count == active
  end

  defp set_owner_counts(owner_id, server_count: server_count, active_server_count: active) do
    {1, nil} =
      Repo.update_all(
        from(o in ServerOwner, where: o.id == ^owner_id),
        set: [server_count: server_count, active_server_count: active]
      )

    :ok
  end

  defp subscribe(%Server{} = server) do
    :ok = PubSub.subscribe_server(server.id)
    :ok = PubSub.subscribe_server_group_servers(server.group_id)
    :ok = PubSub.subscribe_server_owner_servers(server.owner_id)
  end

  defp owner_name(%ServerOwner{group_member: %{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil
end
