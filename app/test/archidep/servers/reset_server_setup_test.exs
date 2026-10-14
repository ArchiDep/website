defmodule ArchiDep.Servers.ResetServerSetupTest do
  # Covers both arities of `reset_server_setup`: the database-mutating
  # `reset_server_setup(auth, %Server{})` that forgets a server's setup, and the
  # binary-ID `reset_server_setup(auth, server_id)` that fetches and authorizes
  # the server, ensures it is tracked, then serializes the reset through the
  # server-tracking processes (which are mocked here).
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Events.ServerSetupReset
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerOwnerCounters
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorClientMock
  alias ArchiDep.Servers.UseCases.ResetServerSetup
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Resetting a server's setup only updates its own row; the properties and
  # counters tables are watched to pin that it never inserts or removes rows
  # there.
  @affected_tables [Server, ServerProperties, ServerOwnerCounters, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "reset_server_setup/2 (server)" do
    test "resets the setup of a group member's server" do
      {auth, _root} = ServersTestHelpers.register_root(@past)
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)

      server =
        ServersTestHelpers.insert_server(owner.id, class.id,
          set_up_at: @past,
          open_ports_checked_at: nil
        )

      assert_reset(auth, server)
    end

    test "resets the setup of a server whose open ports have been checked" do
      {auth, root} = ServersTestHelpers.register_root(@past)
      group = CourseFactory.insert(:class, now: @past)

      server =
        ServersTestHelpers.insert_server(root.id, group.id,
          set_up_at: @past,
          open_ports_checked_at: @past
        )

      assert_reset(auth, server)
    end

    test "refuses a server that has not been set up" do
      {auth, root} = ServersTestHelpers.register_root(@past)
      group = CourseFactory.insert(:class, now: @past)
      server = ServersTestHelpers.insert_server(root.id, group.id, set_up_at: nil)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert_raise FunctionClauseError, fn ->
        ResetServerSetup.reset_server_setup(auth, server)
      end

      assert_no_side_effects(server, previous_counts, subscriptions)
    end
  end

  describe "reset_server_setup/2 (binary ID)" do
    test "resets a server's setup through the server-tracking processes" do
      {auth, root} = ServersTestHelpers.register_root(@past)
      group = CourseFactory.insert(:class, now: @past)
      server = ServersTestHelpers.insert_server(root.id, group.id, set_up_at: @past)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)
      expect(ServerManagerClientMock, :reset_server_setup, fn ^server, ^auth -> :ok end)

      assert ResetServerSetup.reset_server_setup(auth, server.id) == :ok

      assert_no_side_effects(server, previous_counts, subscriptions)
    end

    test "passes through a server-busy error" do
      {auth, root} = ServersTestHelpers.register_root(@past)
      group = CourseFactory.insert(:class, now: @past)
      server = ServersTestHelpers.insert_server(root.id, group.id, set_up_at: @past)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)

      expect(ServerManagerClientMock, :reset_server_setup, fn ^server, ^auth ->
        {:error, :server_busy}
      end)

      assert ResetServerSetup.reset_server_setup(auth, server.id) == {:error, :server_busy}

      assert_no_side_effects(server, previous_counts, subscriptions)
    end

    test "rejects a malformed server ID" do
      {auth, _root} = ServersTestHelpers.register_root(@past)
      previous_counts = count_rows(@affected_tables)

      assert ResetServerSetup.reset_server_setup(auth, "not-a-uuid") ==
               {:error, :server_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "rejects an unknown server ID" do
      {auth, _root} = ServersTestHelpers.register_root(@past)
      previous_counts = count_rows(@affected_tables)

      assert ResetServerSetup.reset_server_setup(auth, UUID.generate()) ==
               {:error, :server_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "masks the server's own non-root owner as a missing server" do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id, set_up_at: @past)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert ResetServerSetup.reset_server_setup(auth, server.id) == {:error, :server_not_found}

      assert_no_side_effects(server, previous_counts, subscriptions)
    end

    test "masks another non-root group member as a missing server" do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      %{auth: other} = ServersTestHelpers.register_group_member(@past, class: class)
      server = ServersTestHelpers.insert_server(owner.id, class.id, set_up_at: @past)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert ResetServerSetup.reset_server_setup(other, server.id) ==
               {:error, :server_not_found}

      assert_no_side_effects(server, previous_counts, subscriptions)
    end
  end

  # Drives a reset and runs the full set of assertions: the returned server, the
  # audit event, the persisted row, the row-count diff and the broadcasts.
  defp assert_reset(auth, %Server{} = server) do
    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    assert {:ok, reset, %EventReference{} = ref} =
             ResetServerSetup.reset_server_setup(auth, server)

    assert reset == %{
             server
             | set_up_at: nil,
               open_ports_checked_at: nil,
               version: server.version + 1,
               updated_at: @now
           }

    server
    |> assert_server_setup_reset_event(auth, ref)
    |> assert_persisted_server(server)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_server_setup_reset_broadcast(subscriptions, server, ref)
  end

  # Asserts the single stored event against the original server: a reset leaves
  # every field the event carries unchanged and bumps the version.
  defp assert_server_setup_reset_event(%Server{id: id} = server, auth, %EventReference{} = ref) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()
    assert ref == StoredEvent.to_reference(event)

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: server.version + 1,
             schema_version: 1,
             type: "archidep/servers/server-setup-reset",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
               "username" => server.username,
               "app_username" => server.app_username,
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

    event
  end

  # Asserts the persisted `servers` row (associations unloaded) rebuilt from the
  # audit event. The event's type implies the cleared setup and open-ports
  # timestamps, and its occurrence the new `updated_at`; the fields it does not
  # carry come from the original server, which a reset leaves untouched.
  defp assert_persisted_server(
         %StoredEvent{data: event_data, version: version, occurred_at: occurred_at},
         original
       ) do
    id = event_data["id"]

    assert Repo.get!(Server, id) == %Server{
             __meta__: loaded(Server, "servers"),
             id: id,
             name: event_data["name"],
             ip_address: parse_inet(event_data["ip_address"]),
             username: event_data["username"],
             app_username: event_data["app_username"],
             ssh_port: event_data["ssh_port"],
             ssh_host_keys: original.ssh_host_keys,
             secret_key: original.secret_key,
             active: original.active,
             group: not_loaded(:group, Server),
             group_id: event_data["group"]["id"],
             owner: not_loaded(:owner, Server),
             owner_id: event_data["owner"]["id"],
             expected_properties: not_loaded(:expected_properties, Server),
             expected_properties_id: original.expected_properties_id,
             last_known_properties: not_loaded(:last_known_properties, Server),
             last_known_properties_id: original.last_known_properties_id,
             version: version,
             created_at: original.created_at,
             set_up_at: nil,
             open_ports_checked_at: nil,
             updated_at: occurred_at
           }
  end

  # Asserts the setup-reset broadcast reached each of the three topics exactly
  # once, carrying the event built from the original server and its reference.
  defp assert_server_setup_reset_broadcast(
         subscriptions,
         %Server{} = server,
         %EventReference{} = ref
       ) do
    event = ServerSetupReset.new(server)

    assert received_broadcasts(subscriptions.server) == [{:server_updated, event, ref}]
    assert received_broadcasts(subscriptions.group) == [{:server_updated, event, ref}]
    assert received_broadcasts(subscriptions.owner) == [{:server_updated, event, ref}]
  end

  defp assert_no_side_effects(%Server{} = server, previous_counts, subscriptions) do
    ServersTestHelpers.assert_server_unchanged(server)
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(subscriptions.server) == []
    assert received_broadcasts(subscriptions.group) == []
    assert received_broadcasts(subscriptions.owner) == []
  end

  # Subscribes each of the three topics a server-updated broadcast reaches in
  # its own collector, so each topic's delivery can be asserted independently.
  defp subscribe(%Server{} = server) do
    %{
      server: collect_broadcasts(fn -> PubSub.subscribe_server(server.id) end),
      group: collect_broadcasts(fn -> PubSub.subscribe_server_group_servers(server.group_id) end),
      owner: collect_broadcasts(fn -> PubSub.subscribe_server_owner_servers(server.owner_id) end)
    }
  end

  defp owner_name(%ServerOwner{group_member: %{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil

  # Re-derives the stored `Postgrex.INET` (including the netmask the cast
  # applies) from the event's address string, the same way the schema casts it.
  defp parse_inet(string) do
    {:ok, inet} = EctoNetwork.INET.cast(string)
    inet
  end
end
