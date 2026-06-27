defmodule ArchiDep.Servers.ReadServersTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersTestHelpers

  # A fixed past instant for the persisted owner/group fixtures.
  @past ~U[2023-09-15 09:42:17.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{
      list_my_servers: protect({Context, :list_my_servers, 1}, Behaviour),
      fetch_server: protect({Context, :fetch_server, 2}, Behaviour),
      fetch_active_server_for_group_member:
        protect({Context, :fetch_active_server_for_group_member, 2}, Behaviour)
    }
  end

  describe "list_my_servers/1" do
    test "lists the authenticated owner's servers ordered by name, username then IP address", %{
      list_my_servers: list_my_servers
    } do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)

      # Inserted out of order to prove the query sorts rather than returning
      # insertion order. The two unnamed servers tie on `name` (NULL, sorted
      # last under `asc`) and break on `username`.
      beta =
        ServersTestHelpers.insert_server(owner.id, class.id, name: "beta", username: "user-z")

      unnamed_a =
        ServersTestHelpers.insert_server(owner.id, class.id, name: nil, username: "user-a")

      alpha =
        ServersTestHelpers.insert_server(owner.id, class.id, name: "alpha", username: "user-m")

      unnamed_b =
        ServersTestHelpers.insert_server(owner.id, class.id, name: nil, username: "user-b")

      # A server owned by someone else must be excluded.
      %{owner: other_owner, class: other_class} = ServersTestHelpers.register_group_member(@past)
      _other = ServersTestHelpers.insert_server(other_owner.id, other_class.id, name: "aaa")

      assert list_my_servers.(auth) == [alpha, beta, unnamed_a, unnamed_b]

      assert_no_stored_events!()
    end

    test "returns an empty list when the owner has no servers", %{
      list_my_servers: list_my_servers
    } do
      %{auth: auth} = ServersTestHelpers.register_group_member(@past)

      assert list_my_servers.(auth) == []

      assert_no_stored_events!()
    end
  end

  describe "fetch_server/2" do
    test "fetches a server that belongs to the authenticated owner", %{fetch_server: fetch_server} do
      %{auth: auth, owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)

      assert fetch_server.(auth, server.id) == {:ok, server}

      assert_no_stored_events!()
    end

    test "a root user can fetch any server", %{fetch_server: fetch_server} do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)

      root = Factory.build(:authentication, root: true)

      assert fetch_server.(root, server.id) == {:ok, server}

      assert_no_stored_events!()
    end

    test "fetching an unknown server returns a not-found error", %{fetch_server: fetch_server} do
      auth = Factory.build(:authentication, root: true)

      assert fetch_server.(auth, Ecto.UUID.generate()) == {:error, :server_not_found}

      assert_no_stored_events!()
    end

    test "fetching another owner's server is masked as not-found", %{fetch_server: fetch_server} do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)

      # A different non-root principal must not learn the server exists.
      %{auth: other_auth} = ServersTestHelpers.register_group_member(@past)

      assert fetch_server.(other_auth, server.id) == {:error, :server_not_found}

      assert_no_stored_events!()
    end
  end

  describe "fetch_active_server_for_group_member/2" do
    setup do
      stub(ArchiDep.Clock.Mock, :now, fn -> @past end)
      :ok
    end

    test "fetches the active server of a group member", %{
      fetch_active_server_for_group_member: fetch_active_server_for_group_member
    } do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@past)

      server = ServersTestHelpers.insert_server(owner.id, class.id, active: true)

      root = Factory.build(:authentication, root: true)

      assert fetch_active_server_for_group_member.(root, student.id) == {:ok, server}

      assert_no_stored_events!()
    end

    test "returns not-found when the group member has no active server", %{
      fetch_active_server_for_group_member: fetch_active_server_for_group_member
    } do
      root = Factory.build(:authentication, root: true)

      assert fetch_active_server_for_group_member.(root, Ecto.UUID.generate()) ==
               {:error, :server_not_found}

      assert_no_stored_events!()
    end

    test "an inactive server is masked as not-found", %{
      fetch_active_server_for_group_member: fetch_active_server_for_group_member
    } do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@past)

      ServersTestHelpers.insert_server(owner.id, class.id, active: false)

      root = Factory.build(:authentication, root: true)

      assert fetch_active_server_for_group_member.(root, student.id) ==
               {:error, :server_not_found}

      assert_no_stored_events!()
    end

    test "a non-root caller is masked as not-found", %{
      fetch_active_server_for_group_member: fetch_active_server_for_group_member
    } do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@past)

      ServersTestHelpers.insert_server(owner.id, class.id, active: true)

      %{auth: other_auth} = ServersTestHelpers.register_group_member(@past)

      assert fetch_active_server_for_group_member.(other_auth, student.id) ==
               {:error, :server_not_found}

      assert_no_stored_events!()
    end
  end
end
