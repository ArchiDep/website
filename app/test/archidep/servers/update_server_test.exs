defmodule ArchiDep.Servers.UpdateServerTest do
  # Covers both arities of `update_server`: the database-mutating
  # `update_server(auth, %Server{}, data)` that rewrites a server's columns, and
  # the binary-ID `update_server(auth, server_id, data)` that fetches and
  # authorizes the server, ensures it is tracked, then serializes the change
  # through the server-tracking processes (which are mocked here).
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerOwnerCounters
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorClientMock
  alias ArchiDep.Servers.UseCases.UpdateServer
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias ArchiDep.Support.SSHFactory
  alias Ecto.UUID

  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Toggling a server's active flag updates the owner's counters row (an update,
  # so its row count is unchanged); it is watched to pin that an update never
  # inserts or removes a counters row.
  @affected_tables [Server, ServerProperties, ServerOwnerCounters, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "update_server/3 (root)" do
    test "updates every field of a minimal server", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()

      server =
        ServersTestHelpers.insert_server(owner_id, group_id,
          name: nil,
          ssh_port: nil,
          active: false,
          properties: [
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
        )

      data = %{
        name: "Full Server",
        ip_address: "203.0.113.42",
        username: "fulluser",
        ssh_port: 2222,
        ssh_host_key_fingerprints: SSHFactory.random_ssh_host_key_fingerprint_string(),
        active: false,
        app_username: "fullapp",
        expected_properties: %{
          hostname: "host.example.com",
          machine_id: "abc123",
          cpus: 4,
          cores: 8,
          vcpus: 16,
          memory: 2048,
          swap: 1024,
          system: "Linux",
          architecture: "x86_64",
          os_family: "Debian",
          distribution: "Ubuntu",
          distribution_release: "jammy",
          distribution_version: "22.04"
        }
      }

      assert_root_update(auth, server, data)
    end

    test "clears every optional field of a full server", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()

      server =
        ServersTestHelpers.insert_server(owner_id, group_id,
          name: "Full",
          ssh_port: 2222,
          active: false,
          properties: [
            hostname: "host.example.com",
            machine_id: "abc123",
            cpus: 4,
            cores: 8,
            vcpus: 16,
            memory: 2048,
            swap: 1024,
            system: "Linux",
            architecture: "x86_64",
            os_family: "Debian",
            distribution: "Ubuntu",
            distribution_release: "jammy",
            distribution_version: "22.04"
          ]
        )

      data = %{
        name: nil,
        ip_address: "192.168.1.10",
        username: "alice",
        ssh_port: nil,
        ssh_host_key_fingerprints: SSHFactory.random_ssh_host_key_fingerprint_string(),
        active: false,
        app_username: "appalice",
        expected_properties: %{
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
        }
      }

      assert_root_update(auth, server, data)
    end

    test "updates a server with random data", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)

      assert_root_update(auth, server, ServersFactory.random_server_data(active: false))
    end

    test "activating a server increments the owner's active-server count", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      set_owner_counts(owner_id, server_count: 1, active_server_count: 0)
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)

      assert_root_update(auth, server, ServersFactory.random_server_data(active: true))

      assert_owner_counters(owner_id,
        server_count: 1,
        server_count_lock: 1,
        active_server_count: 1,
        active_server_count_lock: 2
      )
    end

    test "deactivating a server decrements the owner's active-server count", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      set_owner_counts(owner_id, server_count: 1, active_server_count: 1)
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: true)

      assert_root_update(auth, server, ServersFactory.random_server_data(active: false))

      assert_owner_counters(owner_id,
        server_count: 1,
        server_count_lock: 1,
        active_server_count: 0,
        active_server_count_lock: 2
      )
    end

    test "keeping a server's own name succeeds", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false, name: "Keep")

      assert_root_update(
        auth,
        server,
        ServersFactory.random_server_data(name: "Keep", active: false)
      )
    end

    test "rejects invalid data without writing anything", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)

      data = ServersFactory.random_server_data(ip_address: "not-an-ip")

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert {:error, changeset} = UpdateServer.update_server(auth, server, data)
      assert errors_on(changeset) == %{ip_address: ["is invalid"]}

      ServersTestHelpers.assert_server_unchanged(server)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      assert_no_broadcast(subscriptions)
    end

    test "renaming to another server's name in the group is rejected", %{} do
      {auth, owner_id, group_id} = root_owner_and_group()
      _taken = ServersTestHelpers.insert_server(owner_id, group_id, active: false, name: "Taken")

      server =
        ServersTestHelpers.insert_server(owner_id, group_id, active: false, name: "Original")

      data = ServersFactory.random_server_data(name: "Taken", active: false)

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert {:error, changeset} = UpdateServer.update_server(auth, server, data)
      assert errors_on(changeset) == %{name: ["has already been taken"]}

      ServersTestHelpers.assert_server_unchanged(server)
      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      assert_no_broadcast(subscriptions)
    end
  end

  describe "update_server/3 (group member)" do
    test "updates a server, leaving app username and expected properties untouched", %{} do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)

      server =
        ServersTestHelpers.insert_server(owner.id, class.id,
          active: false,
          app_username: "archidep"
        )

      # A group member cannot change the app username or the expected properties.
      data = ServersFactory.random_server_data(active: false, app_username: "ignored")

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      assert {:ok, updated, %EventReference{} = ref} =
               UpdateServer.update_server(auth, server, data)

      assert %Server{ip_address: ip_address} = updated

      assert updated == %{
               server
               | name: data.name,
                 ip_address: ip_address,
                 username: data.username,
                 ssh_port: data.ssh_port,
                 ssh_host_key_fingerprints: data.ssh_host_key_fingerprints,
                 active: data.active,
                 version: server.version + 1,
                 updated_at: @now
             }

      assert to_string(:inet.ntoa(ip_address.address)) == data.ip_address

      updated
      |> assert_server_updated_event(auth, ref)
      |> assert_persisted_server(server)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
      assert_server_updated_broadcast(subscriptions, updated)
    end
  end

  describe "update_server/3 (binary ID)" do
    test "updates a server through the server-tracking processes" do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      ref = EventsFactory.build(:event_reference)
      previous_counts = count_rows(@affected_tables)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)

      expect(ServerManagerClientMock, :update_server, fn ^server, ^auth, ^data ->
        {:ok, server, ref}
      end)

      assert UpdateServer.update_server(auth, server.id, data) == {:ok, server, ref}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "a non-root owner updates their own server through the tracking processes" do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id, active: false)
      data = ServersFactory.random_server_data(active: false)
      ref = EventsFactory.build(:event_reference)
      previous_counts = count_rows(@affected_tables)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)

      expect(ServerManagerClientMock, :update_server, fn ^server, ^auth, ^data ->
        {:ok, server, ref}
      end)

      assert UpdateServer.update_server(auth, server.id, data) == {:ok, server, ref}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "passes through a changeset error" do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      changeset = Server.update(server, data, @now)
      previous_counts = count_rows(@affected_tables)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)

      expect(ServerManagerClientMock, :update_server, fn ^server, ^auth, ^data ->
        {:error, changeset}
      end)

      assert UpdateServer.update_server(auth, server.id, data) == {:error, changeset}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "passes through a server-busy error" do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      expect(ServersOrchestratorClientMock, :ensure_started, fn ^server -> :ok end)

      expect(ServerManagerClientMock, :update_server, fn ^server, ^auth, ^data ->
        {:error, :server_busy}
      end)

      assert UpdateServer.update_server(auth, server.id, data) == {:error, :server_busy}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "rejects a malformed server ID" do
      {auth, _owner_id, _group_id} = root_owner_and_group()
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      assert UpdateServer.update_server(auth, "not-a-uuid", data) == {:error, :server_not_found}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "rejects an unknown server ID" do
      {auth, _owner_id, _group_id} = root_owner_and_group()
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      assert UpdateServer.update_server(auth, UUID.generate(), data) ==
               {:error, :server_not_found}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "masks an unauthorized caller as a missing server" do
      {_auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      other = Factory.build(:authentication, principal_id: UUID.generate(), root: false)
      previous_counts = count_rows(@affected_tables)

      assert UpdateServer.update_server(other, server.id, data) == {:error, :server_not_found}

      assert_no_tracking_side_effects(previous_counts)
    end
  end

  describe "validate_existing_server/3" do
    test "returns a changeset for a root caller without writing anything" do
      {auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} =
               UpdateServer.validate_existing_server(auth, server.id, data)

      assert errors_on(changeset) == %{}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "returns a changeset for the non-root owner without writing anything" do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id, active: false)
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} =
               UpdateServer.validate_existing_server(auth, server.id, data)

      assert errors_on(changeset) == %{}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "masks a non-owner as a missing server" do
      {_auth, owner_id, group_id} = root_owner_and_group()
      server = ServersTestHelpers.insert_server(owner_id, group_id, active: false)
      data = ServersFactory.random_server_data(active: false)
      other = Factory.build(:authentication, principal_id: UUID.generate(), root: false)
      previous_counts = count_rows(@affected_tables)

      assert UpdateServer.validate_existing_server(other, server.id, data) ==
               {:error, :server_not_found}

      assert_no_tracking_side_effects(previous_counts)
    end

    test "reports an unknown server as not-found" do
      {auth, _owner_id, _group_id} = root_owner_and_group()
      data = ServersFactory.random_server_data(active: false)
      previous_counts = count_rows(@affected_tables)

      assert UpdateServer.validate_existing_server(auth, UUID.generate(), data) ==
               {:error, :server_not_found}

      assert_no_tracking_side_effects(previous_counts)
    end
  end

  # Drives a root update and runs the full set of assertions: the returned
  # server, the audit event, the persisted row, the row-count diff and the
  # broadcasts.
  defp assert_root_update(auth, server, data) do
    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    assert {:ok, updated, %EventReference{} = ref} =
             UpdateServer.update_server(auth, server, data)

    updated
    |> assert_updated_server(server, data)
    |> assert_server_updated_event(auth, ref)
    |> assert_persisted_server(server)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_server_updated_broadcast(subscriptions, updated)

    updated
  end

  defp root_owner_and_group do
    {auth, account} = ServersTestHelpers.register_root(@past)
    group = CourseFactory.insert(:class, now: @past)
    {auth, account.id, group.id}
  end

  defp assert_no_tracking_side_effects(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  # Asserts the returned server: every field overwritten by `data` (the root
  # changeset casts the app username and the expected properties too), version
  # bumped and `updated_at` advanced to `@now`, everything else unchanged.
  defp assert_updated_server(%Server{} = updated, %Server{} = server, data) do
    assert %Server{ip_address: ip_address} = updated

    %ServerProperties{} = current_properties = server.expected_properties

    expected_properties = %{
      current_properties
      | hostname: data.expected_properties.hostname,
        machine_id: data.expected_properties.machine_id,
        cpus: data.expected_properties.cpus,
        cores: data.expected_properties.cores,
        vcpus: data.expected_properties.vcpus,
        memory: data.expected_properties.memory,
        swap: data.expected_properties.swap,
        system: data.expected_properties.system,
        architecture: data.expected_properties.architecture,
        os_family: data.expected_properties.os_family,
        distribution: data.expected_properties.distribution,
        distribution_release: data.expected_properties.distribution_release,
        distribution_version: data.expected_properties.distribution_version
    }

    assert updated == %{
             server
             | name: data.name,
               ip_address: ip_address,
               username: data.username,
               app_username: data.app_username,
               ssh_port: data.ssh_port,
               ssh_host_key_fingerprints: data.ssh_host_key_fingerprints,
               active: data.active,
               expected_properties: expected_properties,
               version: server.version + 1,
               updated_at: @now
           }

    assert to_string(:inet.ntoa(ip_address.address)) == data.ip_address

    updated
  end

  defp assert_server_updated_event(%Server{id: id} = server, auth, %EventReference{} = ref) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()
    assert ref == StoredEvent.to_reference(event)

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: server.version,
             type: "archidep/servers/server-updated",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
               "username" => server.username,
               "app_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "ssh_host_key_fingerprints" => server.ssh_host_key_fingerprints,
               "active" => server.active,
               "group" => %{"id" => server.group.id, "name" => server.group.name},
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" => owner_name(server.owner),
                 "root" => server.owner.root
               },
               "expected_properties" => expected_properties_data(server.expected_properties)
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
  # audit event, proving the row was updated. The fields the event does not
  # carry come from the unchanged prior state of the original server (an update
  # leaves them): the secret key, the creation/setup timestamps and the
  # last-known-properties link.
  defp assert_persisted_server(
         %StoredEvent{data: event_data, version: version},
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
             ssh_host_key_fingerprints: event_data["ssh_host_key_fingerprints"],
             secret_key: original.secret_key,
             active: event_data["active"],
             group: not_loaded(:group, Server),
             group_id: event_data["group"]["id"],
             owner: not_loaded(:owner, Server),
             owner_id: event_data["owner"]["id"],
             expected_properties: not_loaded(:expected_properties, Server),
             expected_properties_id: id,
             last_known_properties: not_loaded(:last_known_properties, Server),
             last_known_properties_id: original.last_known_properties_id,
             version: version,
             created_at: original.created_at,
             set_up_at: original.set_up_at,
             open_ports_checked_at: original.open_ports_checked_at,
             updated_at: @now
           }
  end

  # Asserts the server-updated broadcast reached each of the three topics
  # exactly once and carried the full server. Each topic's collector yields its
  # own list, so a double broadcast on one topic or a missing broadcast on
  # another fails the corresponding whole-list equality.
  defp assert_server_updated_broadcast(subscriptions, %Server{} = server) do
    assert received_broadcasts(subscriptions.server) == [{:server_updated, server}]
    assert received_broadcasts(subscriptions.group) == [{:server_updated, server}]
    assert received_broadcasts(subscriptions.owner) == [{:server_updated, server}]
  end

  # Asserts a rejected call announced nothing on any of the three topics.
  defp assert_no_broadcast(subscriptions) do
    assert received_broadcasts(subscriptions.server) == []
    assert received_broadcasts(subscriptions.group) == []
    assert received_broadcasts(subscriptions.owner) == []
  end

  defp assert_owner_counters(owner_id,
         server_count: server_count,
         server_count_lock: server_count_lock,
         active_server_count: active_server_count,
         active_server_count_lock: active_server_count_lock
       ) do
    assert Repo.get!(ServerOwnerCounters, owner_id) == %ServerOwnerCounters{
             __meta__: loaded(ServerOwnerCounters, "server_owner_counters"),
             user_account_id: owner_id,
             server_count: server_count,
             server_count_lock: server_count_lock,
             active_server_count: active_server_count,
             active_server_count_lock: active_server_count_lock
           }
  end

  defp set_owner_counts(owner_id, server_count: server_count, active_server_count: active),
    do:
      Repo.insert!(%ServerOwnerCounters{
        user_account_id: owner_id,
        server_count: server_count,
        server_count_lock: 1,
        active_server_count: active,
        active_server_count_lock: 1
      })

  # Subscribes each of the three topics a server-updated broadcast reaches in
  # its own collector, so each topic's delivery can be asserted independently
  # rather than funnelled into one indistinguishable mailbox.
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

  defp expected_properties_data(%ServerProperties{} = properties) do
    %{
      "hostname" => properties.hostname,
      "machine_id" => properties.machine_id,
      "cpus" => properties.cpus,
      "cores" => properties.cores,
      "vcpus" => properties.vcpus,
      "memory" => properties.memory,
      "swap" => properties.swap,
      "system" => properties.system,
      "architecture" => properties.architecture,
      "os_family" => properties.os_family,
      "distribution" => properties.distribution,
      "distribution_release" => properties.distribution_release,
      "distribution_version" => properties.distribution_version
    }
  end
end
