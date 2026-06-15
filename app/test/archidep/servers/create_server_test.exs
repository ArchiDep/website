defmodule ArchiDep.Servers.CreateServerTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.TokenTestHelpers, only: [assert_secure_random_token: 1]
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Clock
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias ArchiDep.Support.SSHFactory

  # Pinned instant returned by the injected clock, so every timestamp the use
  # case stamps can be asserted exactly (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # A safely-past instant for the persisted owner/group fixtures, so the created
  # server is visibly stamped at `@now`.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Every table this use case can affect: it inserts a server, its expected
  # properties and the audit event, and updates the owner's server counts (an
  # update, so the `user_accounts` row count must stay put).
  @affected_tables [Server, ServerProperties, StoredEvent, UserAccount]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      create_server: protect({Context, :create_server, 3}, Behaviour),
      validate_server: protect({Context, :validate_server, 3}, Behaviour)
    }
  end

  # Root and group-member callers build the server through different changesets,
  # so each gets its own random creation test.

  describe "create_server/3 (root)" do
    test "creates an active server", %{create_server: create_server} do
      {auth, group} = root_group()
      owner = ServerOwner.fetch_authenticated(auth)

      data = ServersFactory.random_server_data(active: true)

      previous_counts = count_rows(@affected_tables)
      subscribe(group, owner)

      assert {:ok, server} = create_server.(auth, group.id, data)

      server
      |> assert_created_server(data, group, owner, data.expected_properties)
      |> assert_server_created_event(auth, group, owner)
      |> assert_persisted_server(server.secret_key)

      assert_row_count_diff(previous_counts, %{
        Server => 1,
        ServerProperties => 1,
        StoredEvent => 1
      })

      assert_owner_counts(owner.id, server_count: 1, active_server_count: 1)
      assert_server_created_broadcast(server)
    end

    test "creates a minimal inactive server, pinning the applied defaults", %{
      create_server: create_server
    } do
      {auth, group} = root_group()
      owner = ServerOwner.fetch_authenticated(auth)

      # Built by hand so the minimal valid set is explicit: no name, no SSH port,
      # inactive, and blank expected properties.
      data = %{
        name: nil,
        ip_address: "192.168.1.10",
        username: "alice",
        ssh_port: nil,
        ssh_host_key_fingerprints: SSHFactory.random_ssh_host_key_fingerprint_string(),
        active: false,
        app_username: "appalice",
        expected_properties: blank_properties_data()
      }

      previous_counts = count_rows(@affected_tables)
      subscribe(group, owner)

      assert {:ok, server} = create_server.(auth, group.id, data)

      server
      |> assert_created_server(data, group, owner, data.expected_properties)
      |> assert_server_created_event(auth, group, owner)
      |> assert_persisted_server(server.secret_key)

      assert_row_count_diff(previous_counts, %{
        Server => 1,
        ServerProperties => 1,
        StoredEvent => 1
      })

      # An inactive server leaves the active-server count untouched.
      assert_owner_counts(owner.id, server_count: 1, active_server_count: 0)
      assert_server_created_broadcast(server)
    end

    test "creates a full server with every optional set", %{create_server: create_server} do
      {auth, group} = root_group()
      owner = ServerOwner.fetch_authenticated(auth)

      data = %{
        name: "Full Server",
        ip_address: "203.0.113.42",
        username: "fulluser",
        ssh_port: 2222,
        ssh_host_key_fingerprints: SSHFactory.random_ssh_host_key_fingerprint_string(),
        active: true,
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

      previous_counts = count_rows(@affected_tables)
      subscribe(group, owner)

      assert {:ok, server} = create_server.(auth, group.id, data)

      server
      |> assert_created_server(data, group, owner, data.expected_properties)
      |> assert_server_created_event(auth, group, owner)
      |> assert_persisted_server(server.secret_key)

      assert_row_count_diff(previous_counts, %{
        Server => 1,
        ServerProperties => 1,
        StoredEvent => 1
      })

      assert_owner_counts(owner.id, server_count: 1, active_server_count: 1)
      assert_server_created_broadcast(server)
    end
  end

  describe "create_server/3 (group member)" do
    test "creates a server in the member's own group", %{create_server: create_server} do
      %{auth: auth, class: class} = ServersTestHelpers.register_group_member(@past)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)
      owner = ServerOwner.fetch_authenticated(auth)

      # A group member's app username is always forced to "archidep" and the
      # expected properties are always blank, regardless of the input.
      data = ServersFactory.random_server_data(active: false, app_username: "ignored")

      previous_counts = count_rows(@affected_tables)
      subscribe(group, owner)

      assert {:ok, server} = create_server.(auth, group.id, data)

      server
      |> assert_created_server(
        %{data | app_username: "archidep"},
        group,
        owner,
        blank_properties_data()
      )
      |> assert_server_created_event(auth, group, owner)
      |> assert_persisted_server(server.secret_key)

      assert_row_count_diff(previous_counts, %{
        Server => 1,
        ServerProperties => 1,
        StoredEvent => 1
      })

      assert_owner_counts(owner.id, server_count: 1, active_server_count: 0)
      assert_server_created_broadcast(server)
    end
  end

  describe "create_server/3 errors" do
    test "rejects invalid data without writing anything", %{create_server: create_server} do
      {auth, group} = root_group()
      data = ServersFactory.random_server_data(ip_address: "not-an-ip")

      previous_counts = count_rows(@affected_tables)

      assert {:error, changeset} = create_server.(auth, group.id, data)
      assert errors_on(changeset) == %{ip_address: ["is invalid"]}

      assert_no_side_effects(previous_counts)
    end

    test "rejects a server whose name is already taken in the group", %{
      create_server: create_server
    } do
      {auth, group} = root_group()
      existing = ServersTestHelpers.insert_server(auth.principal_id, group.id, name: "Taken")

      data = ServersFactory.random_server_data(name: "Taken")

      previous_counts = count_rows(@affected_tables)

      assert {:error, changeset} = create_server.(auth, group.id, data)
      assert errors_on(changeset) == %{name: ["has already been taken"]}

      # The pre-existing server is untouched and nothing new was written.
      ServersTestHelpers.assert_server_unchanged(existing)
      assert_no_side_effects(previous_counts)
    end

    test "an unknown group is reported as not-found", %{create_server: create_server} do
      {auth, _group} = root_group()

      previous_counts = count_rows(@affected_tables)

      assert create_server.(auth, Ecto.UUID.generate(), ServersFactory.random_server_data()) ==
               {:error, :server_group_not_found}

      assert_no_side_effects(previous_counts)
    end

    # A denied non-root caller is masked as not-found so the group's existence
    # is not leaked to someone who cannot create servers in it.
    test "a non-root caller without servers enabled is masked as not-found", %{
      create_server: create_server
    } do
      %{auth: auth, class: class} =
        ServersTestHelpers.register_group_member(@past,
          class: [servers_enabled: false],
          student: [servers_enabled: false]
        )

      previous_counts = count_rows(@affected_tables)

      assert create_server.(auth, class.id, ServersFactory.random_server_data()) ==
               {:error, :server_group_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "a non-root caller with an unconfirmed username is masked as not-found", %{
      create_server: create_server
    } do
      %{auth: auth, class: class} =
        ServersTestHelpers.register_group_member(@past, student: [username_confirmed: false])

      previous_counts = count_rows(@affected_tables)

      assert create_server.(auth, class.id, ServersFactory.random_server_data()) ==
               {:error, :server_group_not_found}

      assert_no_side_effects(previous_counts)
    end

    test "a group member at the active-server limit cannot create another active server", %{
      create_server: create_server
    } do
      %{auth: auth, class: class, owner: owner} = ServersTestHelpers.register_group_member(@past)
      set_owner_counts(owner.id, server_count: 1, active_server_count: 1)

      data = ServersFactory.random_server_data(active: true)

      previous_counts = count_rows(@affected_tables)

      assert {:error, changeset} = create_server.(auth, class.id, data)
      # The `{current}` placeholder is resolved by the translation layer at
      # render time, so it is asserted literally here.
      assert errors_on(changeset) == %{active: ["active server limit reached (max {current})"]}

      assert_no_side_effects(previous_counts)
    end
  end

  describe "validate_server/3" do
    test "returns a changeset for valid data without writing anything", %{
      validate_server: validate_server
    } do
      {auth, group} = root_group()
      data = ServersFactory.random_server_data()

      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} = validate_server.(auth, group.id, data)
      assert errors_on(changeset) == %{}

      assert_no_side_effects(previous_counts)
    end

    test "surfaces validation errors without writing anything", %{
      validate_server: validate_server
    } do
      {auth, group} = root_group()
      data = ServersFactory.random_server_data(ip_address: "not-an-ip")

      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} = validate_server.(auth, group.id, data)
      assert errors_on(changeset) == %{ip_address: ["is invalid"]}

      assert_no_side_effects(previous_counts)
    end

    test "a non-root caller without servers enabled is masked as not-found", %{
      validate_server: validate_server
    } do
      %{auth: auth, class: class} =
        ServersTestHelpers.register_group_member(@past,
          class: [servers_enabled: false],
          student: [servers_enabled: false]
        )

      previous_counts = count_rows(@affected_tables)

      assert validate_server.(auth, class.id, ServersFactory.random_server_data()) ==
               {:error, :server_group_not_found}

      assert_no_side_effects(previous_counts)
    end
  end

  defp root_group do
    {auth, _user_account} = ServersTestHelpers.register_root(@past)
    group = CourseFactory.insert(:class, now: @past)
    {:ok, server_group} = ServerGroup.fetch_server_group(group.id)
    {auth, server_group}
  end

  defp subscribe(group, owner) do
    :ok = PubSub.subscribe_server_created()
    :ok = PubSub.subscribe_server_group_servers(group.id)
    :ok = PubSub.subscribe_server_owner_servers(owner.id)
  end

  # Asserts the returned server exactly: every field from the requested data,
  # the generated identity/secret bound from the result, the loaded owner and
  # group, the freshly-built expected properties, and the metadata stamped at
  # `@now`.
  defp assert_created_server(%Server{} = server, data, group, owner, props_map) do
    assert %Server{id: id, secret_key: secret_key, ip_address: ip_address} = server

    expected_properties = build_expected_properties(id, props_map)

    assert server == %Server{
             __meta__: loaded(Server, "servers"),
             id: id,
             name: data.name,
             ip_address: ip_address,
             username: data.username,
             app_username: data.app_username,
             ssh_port: data.ssh_port,
             ssh_host_key_fingerprints: data.ssh_host_key_fingerprints,
             secret_key: secret_key,
             active: data.active,
             group: group,
             group_id: group.id,
             owner: owner,
             owner_id: owner.id,
             expected_properties: expected_properties,
             expected_properties_id: id,
             last_known_properties: not_loaded(:last_known_properties, Server),
             last_known_properties_id: nil,
             version: 1,
             created_at: @now,
             set_up_at: nil,
             open_ports_checked_at: nil,
             updated_at: @now
           }

    assert_secure_random_token(secret_key)
    assert to_string(:inet.ntoa(ip_address.address)) == data.ip_address

    server
  end

  defp assert_server_created_event(%Server{id: id} = server, auth, group, owner) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: 1,
             type: "archidep/servers/server-created",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
               "username" => server.username,
               "app_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "ssh_host_key_fingerprints" => server.ssh_host_key_fingerprints,
               "active" => server.active,
               "group" => %{"id" => group.id, "name" => group.name},
               "owner" => %{
                 "id" => owner.id,
                 "username" => owner.username,
                 "name" => owner_name(owner),
                 "root" => owner.root
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

  # Asserts the persisted `servers` row (associations unloaded) rebuilt entirely
  # from the audit event, proving the event captures the row. The only field the
  # event does not carry is the random secret key, kept out of the event because
  # it is sensitive, so it is supplied directly.
  defp assert_persisted_server(%StoredEvent{data: event_data}, secret_key) do
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
             secret_key: secret_key,
             active: event_data["active"],
             group: not_loaded(:group, Server),
             group_id: event_data["group"]["id"],
             owner: not_loaded(:owner, Server),
             owner_id: event_data["owner"]["id"],
             expected_properties: not_loaded(:expected_properties, Server),
             expected_properties_id: id,
             last_known_properties: not_loaded(:last_known_properties, Server),
             last_known_properties_id: nil,
             version: 1,
             created_at: @now,
             set_up_at: nil,
             open_ports_checked_at: nil,
             updated_at: @now
           }
  end

  # Re-derives the stored `Postgrex.INET` (including the netmask the cast
  # applies) from the event's address string, the same way the schema casts it.
  defp parse_inet(string) do
    {:ok, inet} = EctoNetwork.INET.cast(string)
    inet
  end

  # TODO DDD: the server-count columns on `user_accounts` are being reshaped by
  # the DDD refactoring, so assert the observable count change rather than
  # pinning the whole `ServerOwner` row.
  defp assert_owner_counts(owner_id, server_count: server_count, active_server_count: active) do
    {:ok, owner} = ServerOwner.fetch_server_owner(owner_id)
    assert owner.server_count == server_count
    assert owner.active_server_count == active
  end

  defp assert_server_created_broadcast(%Server{id: id} = server) do
    assert_receive {:server_created, %Server{id: ^id} = on_new}
    assert_receive {:server_created, %Server{id: ^id} = on_group}
    assert_receive {:server_created, %Server{id: ^id} = on_owner}

    assert on_new == server
    assert on_group == server
    assert on_owner == server

    refute_received {:server_created, %Server{id: ^id}}
  end

  defp assert_no_side_effects(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  defp set_owner_counts(owner_id, server_count: server_count, active_server_count: active) do
    # The server-count columns live on `user_accounts` but are mapped by the
    # `ServerOwner` view-schema, not `UserAccount`.
    {1, nil} =
      Repo.update_all(
        from(o in ServerOwner, where: o.id == ^owner_id),
        set: [server_count: server_count, active_server_count: active]
      )

    :ok
  end

  defp owner_name(%ServerOwner{group_member: %{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil

  # The expected properties row the use case builds: a fresh row sharing the
  # server id, carrying the (cast) properties map.
  defp build_expected_properties(id, props) do
    %ServerProperties{
      __meta__: loaded(ServerProperties, "server_properties"),
      id: id,
      hostname: props.hostname,
      machine_id: props.machine_id,
      cpus: props.cpus,
      cores: props.cores,
      vcpus: props.vcpus,
      memory: props.memory,
      swap: props.swap,
      system: props.system,
      architecture: props.architecture,
      os_family: props.os_family,
      distribution: props.distribution,
      distribution_release: props.distribution_release,
      distribution_version: props.distribution_version
    }
  end

  defp blank_properties_data do
    %{
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
