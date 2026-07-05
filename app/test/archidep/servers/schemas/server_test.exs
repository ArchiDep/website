defmodule ArchiDep.Servers.Schemas.ServerTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.Changeset

  # These changeset validations do not depend on the creation timestamp; a fixed
  # instant keeps the changeset calls deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]

  # The tables the persistence functions can write to, watched by every
  # row-count diff in this file.
  @affected_tables [Server, ServerProperties, StoredEvent]

  # `changed?/3` only compares two servers that share an owner and a group, so
  # its fixtures pin both ids to the same fixed values.
  @group_id "11111111-1111-1111-1111-111111111111"
  @owner_id "22222222-2222-2222-2222-222222222222"

  # A safely-past instant for persisted owner/group/server fixtures, so a
  # conflict is set up before the changeset under test runs at `@now`.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # `Server.new/4`, `Server.new_group_member_server/3`, `Server.update/3` and
  # `Server.update_group_member_server/4` all run the same `validate/1` rules.
  # Each rule is written once below and the `for` comprehension generates one
  # test per changeset function; `changeset/2` dispatches to the right
  # constructor. Only rules that validate a *provided* value live here —
  # `validate_required` cannot fail on the update path (an omitted field keeps
  # the persisted value), so the required-field cases live in their own block
  # below, and the uniqueness rules (DB-backed, with self-exclusion on update)
  # have their own blocks too.
  for variant <- [:new, :new_group_member, :update, :update_group_member] do
    describe "#{variant} value validations" do
      test "accepts valid data" do
        assert errors_on(
                 changeset(unquote(variant), username: "validuser", app_username: "validapp")
               ) ==
                 %{}
      end

      test "the name cannot be longer than 50 characters" do
        assert errors_on(changeset(unquote(variant), name: String.duplicate("a", 51))) ==
                 %{name: ["should be at most 50 character(s)"]}
      end

      test "the name is trimmed" do
        assert Changeset.get_change(changeset(unquote(variant), name: "  Spaced  "), :name) ==
                 "Spaced"
      end

      test "the username cannot be longer than 32 characters" do
        assert errors_on(changeset(unquote(variant), username: String.duplicate("a", 33))) ==
                 %{username: ["should be at most 32 character(s)"]}
      end

      test "the SSH port must be greater than 0" do
        assert errors_on(changeset(unquote(variant), ssh_port: 0)) ==
                 %{ssh_port: ["must be greater than 0"]}
      end

      test "the SSH port must be less than 65536" do
        assert errors_on(changeset(unquote(variant), ssh_port: 65_536)) ==
                 %{ssh_port: ["must be less than 65536"]}
      end

      # The server field parses with the `:any` digest, so a line that matches
      # no fingerprint format yields a validation error (it does not crash,
      # unlike the digest-specific parser path).
      test "the SSH host key fingerprints must contain at least one valid fingerprint" do
        assert errors_on(
                 changeset(unquote(variant), ssh_host_key_fingerprints: "not-a-valid-fingerprint")
               ) == %{
                 ssh_host_key_fingerprints: [
                   "must contain at least one valid SSH host key fingerprint, with new lines between each fingerprint"
                 ]
               }
      end

      test "validation errors accumulate across fields" do
        assert errors_on(
                 changeset(unquote(variant),
                   name: String.duplicate("a", 51),
                   ssh_port: 0,
                   ssh_host_key_fingerprints: "not-a-valid-fingerprint"
                 )
               ) == %{
                 name: ["should be at most 50 character(s)"],
                 ssh_port: ["must be greater than 0"],
                 ssh_host_key_fingerprints: [
                   "must contain at least one valid SSH host key fingerprint, with new lines between each fingerprint"
                 ]
               }
      end
    end
  end

  # The two root builders cast the app username from the input and reject it
  # when it equals the username; the group-member builders force it to
  # "archidep" instead, so these rules are root-only.
  for variant <- [:new, :update] do
    describe "#{variant} app username validations" do
      test "the app username cannot be longer than 32 characters" do
        assert errors_on(changeset(unquote(variant), app_username: String.duplicate("a", 33))) ==
                 %{app_username: ["should be at most 32 character(s)"]}
      end

      test "the app username cannot be the same as the username" do
        assert errors_on(
                 changeset(unquote(variant), username: "samename", app_username: "samename")
               ) ==
                 %{app_username: ["cannot be the same as the username"]}
      end
    end
  end

  # Only the group-member builders reject the reserved "archidep" username; the
  # root builders set their own app username and allow any username.
  for variant <- [:new_group_member, :update_group_member] do
    describe "#{variant} reserved username" do
      test "rejects the reserved 'archidep' username" do
        assert errors_on(changeset(unquote(variant), username: "archidep")) ==
                 %{username: ["this username is reserved and cannot be used"]}
      end

      test "rejects the reserved username case-insensitively" do
        assert errors_on(changeset(unquote(variant), username: "ARCHIDEP")) ==
                 %{username: ["this username is reserved and cannot be used"]}
      end
    end
  end

  # Required fields can only fail on the create path; on update an omitted field
  # keeps the persisted value. The app username is cast only by the root create
  # builder, so its requirement is asserted there alone.
  for variant <- [:new, :new_group_member] do
    describe "#{variant} required fields" do
      test "the IP address is required" do
        assert errors_on(changeset(unquote(variant), ip_address: nil)) ==
                 %{ip_address: ["can't be blank"]}
      end

      test "the username is required" do
        assert errors_on(changeset(unquote(variant), username: nil)) ==
                 %{username: ["can't be blank"]}
      end

      test "active is required" do
        assert errors_on(changeset(unquote(variant), active: nil)) ==
                 %{active: ["can't be blank"]}
      end

      test "the SSH host key fingerprints are required" do
        assert errors_on(changeset(unquote(variant), ssh_host_key_fingerprints: nil)) ==
                 %{ssh_host_key_fingerprints: ["can't be blank"]}
      end
    end
  end

  describe "new/4 required fields" do
    test "the app username is required" do
      assert errors_on(changeset(:new, app_username: nil)) ==
               %{app_username: ["can't be blank"]}
    end
  end

  describe "new/4 uniqueness" do
    test "the name must not already be taken in the same group" do
      {owner, group} = persisted_owner_and_group()
      ServersTestHelpers.insert_server(owner.id, group.id, name: "Taken")

      data = ServersFactory.random_server_data(name: "Taken")

      assert errors_on(Server.new(data, group, owner, @now)) ==
               %{name: ["has already been taken"]}
    end

    test "the IP address must not already be in use" do
      {owner, group} = persisted_owner_and_group()
      existing = ServersTestHelpers.insert_server(owner.id, group.id, name: "Existing")

      data = ServersFactory.random_server_data(name: "Different", ip_address: ip_string(existing))

      assert errors_on(Server.new(data, group, owner, @now)) ==
               %{ip_address: ["has already been taken"]}
    end
  end

  describe "update/3 uniqueness" do
    test "the name must not be taken by another server in the same group" do
      {owner, group} = persisted_owner_and_group()
      ServersTestHelpers.insert_server(owner.id, group.id, name: "Taken")
      server = ServersTestHelpers.insert_server(owner.id, group.id, name: "Mine")

      data = ServersFactory.random_server_data(name: "Taken")

      assert errors_on(Server.update(server, data, @now)) ==
               %{name: ["has already been taken"]}
    end

    test "a server can keep its own name" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, name: "Mine")

      data = ServersFactory.random_server_data(name: "Mine")

      assert errors_on(Server.update(server, data, @now)) == %{}
    end

    test "the IP address must not be taken by another server" do
      {owner, group} = persisted_owner_and_group()
      other = ServersTestHelpers.insert_server(owner.id, group.id, name: "Other")
      server = ServersTestHelpers.insert_server(owner.id, group.id, name: "Mine")

      data = ServersFactory.random_server_data(name: "Mine", ip_address: ip_string(other))

      assert errors_on(Server.update(server, data, @now)) ==
               %{ip_address: ["has already been taken"]}
    end

    test "a server can keep its own IP address" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, name: "Mine")

      data = ServersFactory.random_server_data(name: "Mine", ip_address: ip_string(server))

      assert errors_on(Server.update(server, data, @now)) == %{}
    end
  end

  describe "new_group_member_server/3 server limits" do
    test "a group member at the active-server limit cannot create another active server" do
      owner =
        ServersFactory.build(:server_owner, root: false, active_server_count: 1, server_count: 1)

      data = ServersFactory.random_server_data(active: true)

      # The `{current}` placeholder is resolved by the translation layer at
      # render time, so it is asserted literally here.
      assert errors_on(Server.new_group_member_server(data, owner, @now)) ==
               %{active: ["active server limit reached (max {current})"]}
    end

    test "a group member at the server limit cannot create another server" do
      owner =
        ServersFactory.build(:server_owner, root: false, active_server_count: 0, server_count: 5)

      data = ServersFactory.random_server_data(active: false)

      assert errors_on(Server.new_group_member_server(data, owner, @now)) ==
               %{active: ["server limit reached (max {current})"]}
    end
  end

  describe "update_group_member_server/4 server limits" do
    test "a group member at the active-server limit cannot activate another server" do
      owner =
        ServersFactory.build(:server_owner, root: false, active_server_count: 1, server_count: 1)

      server = ServersFactory.build(:server, active: false)
      data = ServersFactory.random_server_data(active: true)

      assert errors_on(Server.update_group_member_server(server, data, owner, @now)) ==
               %{active: ["active server limit reached (max {current})"]}
    end
  end

  describe "mark_as_set_up!/3" do
    test "marks a server as set up and stores a set-up event" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, set_up_at: nil)
      cause = StoredEvent.to_reference(EventsFactory.insert(:stored_event))

      previous_counts = count_rows(@affected_tables)

      updated = Server.mark_as_set_up!(server, cause, @now)

      # The set-up transition stamps `set_up_at` and bumps the version, but
      # deliberately leaves `updated_at` untouched.
      assert updated == %{server | set_up_at: @now, version: server.version + 1}

      updated
      |> assert_server_set_up_event(cause)
      |> assert_persisted_server(server, set_up_at: @now, updated_at: server.updated_at)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end
  end

  describe "mark_open_ports_checked!/4" do
    test "records the checked ports and stores an open-ports-checked event" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, open_ports_checked_at: nil)
      cause = StoredEvent.to_reference(EventsFactory.insert(:stored_event))
      ports = [22, 80, 443]

      previous_counts = count_rows(@affected_tables)

      updated = Server.mark_open_ports_checked!(server, ports, cause, @now)

      assert updated ==
               %{
                 server
                 | open_ports_checked_at: @now,
                   updated_at: @now,
                   version: server.version + 1
               }

      updated
      |> assert_server_open_ports_checked_event(cause, ports)
      |> assert_persisted_server(server, open_ports_checked_at: @now, updated_at: @now)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end
  end

  describe "update_last_known_properties!/4" do
    test "stores the gathered facts as the last known properties and an event" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, last_known_properties: nil)
      cause = StoredEvent.to_reference(EventsFactory.insert(:stored_event))

      facts = %{
        "ansible_nodename" => "host.example.com",
        "ansible_machine_id" => "abc123",
        "ansible_processor_count" => 4,
        "ansible_processor_cores" => 8,
        "ansible_processor_vcpus" => 16,
        "ansible_memory_mb" => %{"real" => %{"total" => 2048}, "swap" => %{"total" => 1024}},
        "ansible_system" => "Linux",
        "ansible_architecture" => "x86_64",
        "ansible_os_family" => "Debian",
        "ansible_distribution" => "Ubuntu",
        "ansible_distribution_release" => "jammy",
        "ansible_distribution_version" => "22.04"
      }

      previous_counts = count_rows(@affected_tables)

      updated = Server.update_last_known_properties!(server, facts, cause, @now)

      assert %Server{last_known_properties: %ServerProperties{id: properties_id}} = updated

      expected_properties = %ServerProperties{
        __meta__: loaded(ServerProperties, "server_properties"),
        id: properties_id,
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

      assert updated == %{
               server
               | last_known_properties: expected_properties,
                 last_known_properties_id: properties_id,
                 updated_at: @now,
                 version: server.version + 1
             }

      updated
      |> assert_server_facts_gathered_event(cause, facts)
      |> assert_persisted_server(server,
        last_known_properties_id: properties_id,
        updated_at: @now
      )

      assert_row_count_diff(previous_counts, %{ServerProperties => 1, StoredEvent => 1})
    end

    # Gathered facts come from an arbitrary server, so an invalid value (here a
    # hostname longer than the column allows) must not reject the whole update:
    # the offending field is cleared while the rest is stored, and the raw facts
    # are still recorded in the audit event.
    test "clears invalid gathered facts instead of failing the update" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, last_known_properties: nil)
      cause = StoredEvent.to_reference(EventsFactory.insert(:stored_event))

      facts = %{
        "ansible_nodename" => String.duplicate("a", 256),
        "ansible_machine_id" => "abc123",
        "ansible_processor_count" => 4,
        "ansible_processor_cores" => 8,
        "ansible_processor_vcpus" => 16,
        "ansible_memory_mb" => %{"real" => %{"total" => 2048}, "swap" => %{"total" => 1024}},
        "ansible_system" => "Linux",
        "ansible_architecture" => "x86_64",
        "ansible_os_family" => "Debian",
        "ansible_distribution" => "Ubuntu",
        "ansible_distribution_release" => "jammy",
        "ansible_distribution_version" => "22.04"
      }

      previous_counts = count_rows(@affected_tables)

      updated = Server.update_last_known_properties!(server, facts, cause, @now)

      assert %Server{last_known_properties: %ServerProperties{id: properties_id}} = updated

      expected_properties = %ServerProperties{
        __meta__: loaded(ServerProperties, "server_properties"),
        id: properties_id,
        hostname: nil,
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

      assert updated == %{
               server
               | last_known_properties: expected_properties,
                 last_known_properties_id: properties_id,
                 updated_at: @now,
                 version: server.version + 1
             }

      updated
      |> assert_server_facts_gathered_event(cause, facts)
      |> assert_persisted_server(server,
        last_known_properties_id: properties_id,
        updated_at: @now
      )

      assert_row_count_diff(previous_counts, %{ServerProperties => 1, StoredEvent => 1})
    end

    test "writes nothing when the facts produce no change" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id, last_known_properties: nil)
      cause = StoredEvent.to_reference(EventsFactory.insert(:stored_event))

      previous_counts = count_rows(@affected_tables)

      assert Server.update_last_known_properties!(server, %{}, cause, @now) == server

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!([cause])
    end
  end

  describe "active?/2" do
    test "is true for an active server in an active group owned by an active root owner" do
      assert Server.active?(active_server([]), @now)
    end

    test "is false when the server itself is inactive" do
      refute Server.active?(active_server(active: false), @now)
    end

    test "is false when the server's group is inactive" do
      group = ServersFactory.build(:server_group, active: false, start_date: nil, end_date: nil)
      refute Server.active?(active_server(group: group), @now)
    end

    test "is false when the owner is inactive" do
      owner = ServersFactory.build(:server_owner, root: true, active: false, group_member: nil)
      refute Server.active?(active_server(owner: owner), @now)
    end

    test "is true when the owner's group member belongs to the server's group" do
      group = ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil)

      member =
        ServersFactory.build(:server_group_member, active: true, group: group, group_id: group.id)

      owner = ServersFactory.build(:server_owner, root: false, active: true, group_member: member)

      assert Server.active?(active_server(group: group, owner: owner), @now)
    end

    test "is false when the owner's group member belongs to a different group" do
      group = ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil)

      other_group =
        ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil)

      member =
        ServersFactory.build(:server_group_member,
          active: true,
          group: other_group,
          group_id: other_group.id
        )

      owner = ServersFactory.build(:server_owner, root: false, active: true, group_member: member)

      refute Server.active?(active_server(group: group, owner: owner), @now)
    end
  end

  describe "set_up?/1" do
    test "is true when the server has a set-up timestamp" do
      assert Server.set_up?(ServersFactory.build(:server, set_up_at: @now))
    end

    test "is false when the server has no set-up timestamp" do
      refute Server.set_up?(ServersFactory.build(:server, set_up_at: nil))
    end
  end

  describe "changed?/3" do
    test "is false when none of the compared fields differ" do
      a = ServersFactory.build(:server, group_id: @group_id, owner_id: @owner_id, name: "Same")
      b = %{a | id: Ecto.UUID.generate()}

      refute Server.changed?(a, b, [:name, :username])
    end

    test "is true when a compared field differs" do
      a = ServersFactory.build(:server, group_id: @group_id, owner_id: @owner_id, name: "Before")
      b = %{a | name: "After"}

      assert Server.changed?(a, b, [:name])
    end

    test "compares the SSH port" do
      a = ServersFactory.build(:server, group_id: @group_id, owner_id: @owner_id, ssh_port: 2222)

      refute Server.changed?(a, %{a | ssh_port: 2222}, [:ssh_port])
      assert Server.changed?(a, %{a | ssh_port: 22}, [:ssh_port])
    end

    test "compares the expected properties through ServerProperties.changed?/2" do
      properties = ServersFactory.build(:server_properties, cpus: 4)

      a =
        ServersFactory.build(:server,
          group_id: @group_id,
          owner_id: @owner_id,
          expected_properties: properties
        )

      refute Server.changed?(a, a, [:expected_properties])

      assert Server.changed?(a, %{a | expected_properties: %{properties | cpus: 8}}, [
               :expected_properties
             ])
    end
  end

  describe "valid_ssh_host_key_fingerprints/1" do
    test "returns the parsed fingerprints" do
      sha256 = :binary.copy(<<1>>, 32)
      line = "256 SHA256:#{Base.encode64(sha256, padding: false)} root@server (ED25519)"
      server = ServersFactory.build(:server, ssh_host_key_fingerprints: line)

      assert Server.valid_ssh_host_key_fingerprints(server) == [
               %SSHKeyFingerprint{fingerprint: {:sha256, sha256}, key_alg: "ED25519", raw: line}
             ]
    end

    test "ignores lines that fail to parse" do
      sha256 = :binary.copy(<<2>>, 32)
      valid = "256 SHA256:#{Base.encode64(sha256, padding: false)} root@server (ED25519)"
      server = ServersFactory.build(:server, ssh_host_key_fingerprints: "#{valid}\nnope")

      assert Server.valid_ssh_host_key_fingerprints(server) == [
               %SSHKeyFingerprint{fingerprint: {:sha256, sha256}, key_alg: "ED25519", raw: valid}
             ]
    end

    test "returns an empty list when no fingerprint is valid" do
      server = ServersFactory.build(:server, ssh_host_key_fingerprints: "not-a-fingerprint")

      assert Server.valid_ssh_host_key_fingerprints(server) == []
    end
  end

  describe "default_hostname/1" do
    test "joins the username and the group member domain" do
      member = ServersFactory.build(:server_group_member, domain: "example.archidep.ch")
      owner = ServersFactory.build(:server_owner, root: false, group_member: member)
      server = ServersFactory.build(:server, username: "alice", owner: owner)

      assert Server.default_hostname(server) == "alice.example.archidep.ch"
    end

    test "is nil when the owner has no group member" do
      owner = ServersFactory.build(:server_owner, root: true, group_member: nil)
      server = ServersFactory.build(:server, owner: owner)

      assert Server.default_hostname(server) == nil
    end
  end

  describe "name_or_default/1" do
    test "returns the name when one is set" do
      assert Server.name_or_default(ServersFactory.build(:server, name: "My Server")) ==
               "My Server"
    end

    test "falls back to the SSH connection description when the name is nil" do
      server =
        ServersFactory.build(:server,
          name: nil,
          username: "bob",
          ip_address: %Postgrex.INET{address: {203, 0, 113, 7}, netmask: nil},
          ssh_port: nil
        )

      assert Server.name_or_default(server) == "bob@203.0.113.7"
    end
  end

  describe "ssh_connection_description/1" do
    test "omits the port when none is set" do
      assert Server.ssh_connection_description(connection_server(ssh_port: nil)) ==
               "bob@203.0.113.7"
    end

    test "omits the port when it is the default SSH port" do
      assert Server.ssh_connection_description(connection_server(ssh_port: 22)) ==
               "bob@203.0.113.7"
    end

    test "includes the port when it differs from the default SSH port" do
      assert Server.ssh_connection_description(connection_server(ssh_port: 2222)) ==
               "bob@203.0.113.7:2222"
    end
  end

  describe "event_stream/1" do
    test "builds the stream from a server id" do
      id = Ecto.UUID.generate()
      assert Server.event_stream(id) == "servers:servers:#{id}"
    end

    test "builds the stream from a server struct" do
      server = ServersFactory.build(:server)
      assert Server.event_stream(server) == "servers:servers:#{server.id}"
    end
  end

  describe "count_active_servers/1" do
    test "counts active servers of active owners, ignoring inactive servers and servers of inactive owners" do
      %{owner: active_owner, class: active_class} =
        ServersTestHelpers.register_group_member(@now)

      %{owner: inactive_owner, class: inactive_class} =
        ServersTestHelpers.register_group_member(@now, student: [active: false])

      ServersTestHelpers.insert_server(active_owner.id, active_class.id, active: true)
      ServersTestHelpers.insert_server(active_owner.id, active_class.id, active: false)
      ServersTestHelpers.insert_server(inactive_owner.id, inactive_class.id, active: true)

      assert Server.count_active_servers(@now) == 1
    end
  end

  defp changeset(:new, overrides) do
    group = ServersFactory.build(:server_group)
    owner = ServersFactory.build(:server_owner, root: true)
    Server.new(server_data(overrides), group, owner, @now)
  end

  defp changeset(:new_group_member, overrides) do
    owner =
      ServersFactory.build(:server_owner, root: false, active_server_count: 0, server_count: 0)

    Server.new_group_member_server(server_data(overrides), owner, @now)
  end

  defp changeset(:update, overrides) do
    server = ServersFactory.build(:server)
    Server.update(server, server_data(overrides), @now)
  end

  defp changeset(:update_group_member, overrides) do
    owner =
      ServersFactory.build(:server_owner, root: false, active_server_count: 0, server_count: 0)

    server = ServersFactory.build(:server)
    Server.update_group_member_server(server, server_data(overrides), owner, @now)
  end

  # A non-active server keeps the group-member builders' active/server-limit
  # validations out of the shared value-rule tests, which target other rules.
  defp server_data(overrides),
    do: ServersFactory.random_server_data(Keyword.merge([active: false], overrides))

  defp persisted_owner_and_group do
    {auth, _user_account} = ServersTestHelpers.register_root(@past)
    class = CourseFactory.insert(:class, now: @past)
    {:ok, group} = ServerGroup.fetch_server_group(class.id)
    owner = ServerOwner.fetch_authenticated(auth)
    {owner, group}
  end

  defp ip_string(%Server{ip_address: ip_address}),
    do: ip_address.address |> :inet.ntoa() |> to_string()

  defp active_server(overrides) do
    group = ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil)
    owner = ServersFactory.build(:server_owner, root: true, active: true, group_member: nil)

    ServersFactory.build(
      :server,
      Keyword.merge([active: true, group: group, owner: owner], overrides)
    )
  end

  defp connection_server(overrides) do
    ServersFactory.build(
      :server,
      Keyword.merge(
        [username: "bob", ip_address: %Postgrex.INET{address: {203, 0, 113, 7}, netmask: nil}],
        overrides
      )
    )
  end

  defp assert_server_set_up_event(%Server{} = server, cause),
    do:
      assert_server_event(
        server,
        cause,
        "archidep/servers/server-set-up",
        server_snapshot_data(server)
      )

  defp assert_server_open_ports_checked_event(%Server{} = server, cause, ports),
    do:
      assert_server_event(
        server,
        cause,
        "archidep/servers/server-open-ports-checked",
        Map.put(server_snapshot_data(server), "ports", ports)
      )

  defp assert_server_facts_gathered_event(%Server{} = server, cause, facts),
    do:
      assert_server_event(
        server,
        cause,
        "archidep/servers/server-facts-gathered",
        Map.put(server_snapshot_data(server), "facts", facts)
      )

  defp assert_server_event(%Server{id: id} = server, cause, type, data) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events([cause])

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: server.version,
             type: type,
             data: data,
             meta: %{},
             initiator: "servers:servers:#{id}",
             causation_id: cause.id,
             correlation_id: cause.correlation_id,
             occurred_at: @now,
             entity: nil
           }

    event
  end

  defp server_snapshot_data(%Server{} = server),
    do: %{
      "id" => server.id,
      "name" => server.name,
      "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
      "username" => server.username,
      "ssh_username" => server.app_username,
      "ssh_port" => server.ssh_port,
      "group" => %{"id" => server.group.id, "name" => server.group.name},
      "owner" => %{
        "id" => server.owner.id,
        "username" => server.owner.username,
        "name" => owner_name(server.owner),
        "root" => server.owner.root
      }
    }

  # Rebuilds the persisted `servers` row from the audit event for every field the
  # event carries, taking the fields the event deliberately omits (the secret
  # key, the active flag, the SSH fingerprints, the timestamps) from the
  # unchanged original. `overrides` carries the fields the persistence function
  # changed.
  defp assert_persisted_server(%StoredEvent{data: data, version: version}, original, overrides) do
    id = data["id"]

    expected = %Server{
      __meta__: loaded(Server, "servers"),
      id: id,
      name: data["name"],
      ip_address: parse_inet(data["ip_address"]),
      username: data["username"],
      app_username: data["ssh_username"],
      ssh_port: data["ssh_port"],
      ssh_host_key_fingerprints: original.ssh_host_key_fingerprints,
      secret_key: original.secret_key,
      active: original.active,
      group: not_loaded(:group, Server),
      group_id: data["group"]["id"],
      owner: not_loaded(:owner, Server),
      owner_id: data["owner"]["id"],
      expected_properties: not_loaded(:expected_properties, Server),
      expected_properties_id: original.expected_properties_id,
      last_known_properties: not_loaded(:last_known_properties, Server),
      last_known_properties_id: original.last_known_properties_id,
      version: version,
      created_at: original.created_at,
      set_up_at: original.set_up_at,
      open_ports_checked_at: original.open_ports_checked_at,
      updated_at: original.updated_at
    }

    assert Repo.get!(Server, id) == struct!(expected, overrides)
  end

  defp owner_name(%ServerOwner{group_member: %ServerGroupMember{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil

  # Re-derives the stored `Postgrex.INET` from the event's address string, the
  # same way the schema casts it.
  defp parse_inet(string) do
    {:ok, inet} = EctoNetwork.INET.cast(string)
    inet
  end
end
