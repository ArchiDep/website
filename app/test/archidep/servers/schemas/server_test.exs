defmodule ArchiDep.Servers.Schemas.ServerTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.Changeset

  # These changeset validations do not depend on the creation timestamp; a fixed
  # instant keeps the changeset calls deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]

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
end
