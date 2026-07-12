defmodule ArchiDep.Servers.ReadServerGroupsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.Association.NotLoaded

  # A fixed past instant for the persisted fixtures.
  @past ~U[2023-09-15 09:42:17.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{
      list_server_groups: protect({Context, :list_server_groups, 1}, Behaviour),
      fetch_server_group: protect({Context, :fetch_server_group, 2}, Behaviour),
      list_server_group_members: protect({Context, :list_server_group_members, 2}, Behaviour),
      fetch_authenticated_server_group_member:
        protect({Context, :fetch_authenticated_server_group_member, 1}, Behaviour),
      list_all_servers_in_group: protect({Context, :list_all_servers_in_group, 2}, Behaviour),
      watch_server_ids: protect({Context, :watch_server_ids, 2}, Behaviour)
    }
  end

  describe "list_server_groups/1" do
    test "lists every group ordered by active, end date, creation then name", %{
      list_server_groups: list_server_groups
    } do
      # Inserted out of order to prove the query sorts. `active` desc comes
      # first, then `end_date` desc (NULLs first under desc), then `created_at`
      # desc, then `name` asc. `a` and `d` share an
      # `active`/`end_date`/`created_at` so only `name` breaks their tie.
      tie_created_at = ~U[2023-01-01 00:00:00.000000Z]
      b = CourseFactory.insert(:class, active: true, end_date: ~D[2025-01-01], now: @past)
      c = CourseFactory.insert(:class, active: false, end_date: ~D[2030-01-01], now: @past)

      a =
        CourseFactory.insert(:class,
          name: "AAA",
          active: true,
          end_date: nil,
          created_at: tie_created_at,
          now: @past
        )

      d =
        CourseFactory.insert(:class,
          name: "ZZZ",
          active: true,
          end_date: nil,
          created_at: tie_created_at,
          now: @past
        )

      auth = Factory.build(:authentication, root: true)

      assert list_server_groups.(auth) == Enum.map([a, d, b, c], &server_group_view/1)

      assert_no_stored_events!()
    end

    test "returns an empty list when there are no groups", %{
      list_server_groups: list_server_groups
    } do
      auth = Factory.build(:authentication, root: true)

      assert list_server_groups.(auth) == []

      assert_no_stored_events!()
    end

    test "a non-root user cannot list server groups", %{list_server_groups: list_server_groups} do
      auth = Factory.build(:authentication, root: false)

      assert_raise UnauthorizedError, fn -> list_server_groups.(auth) end

      assert_no_stored_events!()
    end
  end

  describe "fetch_server_group/2" do
    test "fetches a server group by id", %{fetch_server_group: fetch_server_group} do
      class = CourseFactory.insert(:class, now: @past)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)

      auth = Factory.build(:authentication, root: true)

      assert fetch_server_group.(auth, class.id) == {:ok, group}

      assert_no_stored_events!()
    end

    test "fetching an unknown server group returns a not-found error", %{
      fetch_server_group: fetch_server_group
    } do
      auth = Factory.build(:authentication, root: true)

      assert fetch_server_group.(auth, Ecto.UUID.generate()) ==
               {:error, :server_group_not_found}

      assert_no_stored_events!()
    end

    test "a non-root user fetching a server group is masked as not-found", %{
      fetch_server_group: fetch_server_group
    } do
      class = CourseFactory.insert(:class, now: @past)
      auth = Factory.build(:authentication, root: false)

      assert fetch_server_group.(auth, class.id) == {:error, :server_group_not_found}

      assert_no_stored_events!()
    end
  end

  describe "list_server_group_members/2" do
    test "lists the members of a server group", %{
      list_server_group_members: list_server_group_members
    } do
      %{class: class} = ServersTestHelpers.register_group_member(@past)
      _second = ServersTestHelpers.register_group_member(@past, class: class)

      auth = Factory.build(:authentication, root: true)

      assert {:ok, members} = list_server_group_members.(auth, class.id)

      # The use case returns the ordered schema query verbatim.
      assert members == ServerGroupMember.list_members_in_server_group(class.id)

      assert_no_stored_events!()
    end

    test "listing members of an unknown server group returns a not-found error", %{
      list_server_group_members: list_server_group_members
    } do
      auth = Factory.build(:authentication, root: true)

      assert list_server_group_members.(auth, Ecto.UUID.generate()) ==
               {:error, :server_group_not_found}

      assert_no_stored_events!()
    end

    test "a non-root user listing members is masked as not-found", %{
      list_server_group_members: list_server_group_members
    } do
      class = CourseFactory.insert(:class, now: @past)
      auth = Factory.build(:authentication, root: false)

      assert list_server_group_members.(auth, class.id) == {:error, :server_group_not_found}

      assert_no_stored_events!()
    end
  end

  describe "fetch_authenticated_server_group_member/1" do
    test "fetches the group member for the authenticated owner", %{
      fetch_authenticated_server_group_member: fetch_authenticated_server_group_member
    } do
      %{auth: auth, owner: owner} = ServersTestHelpers.register_group_member(@past)

      assert fetch_authenticated_server_group_member.(auth) ==
               ServerGroupMember.fetch_server_group_member_for_user_account_id(owner.id)

      assert_no_stored_events!()
    end

    test "returns an error when the authenticated user is not a group member", %{
      fetch_authenticated_server_group_member: fetch_authenticated_server_group_member
    } do
      auth = Factory.build(:authentication, root: false)

      assert fetch_authenticated_server_group_member.(auth) ==
               {:error, :not_a_server_group_member}

      assert_no_stored_events!()
    end
  end

  describe "list_all_servers_in_group/2" do
    test "lists the servers of a group ordered by name, username then IP address", %{
      list_all_servers_in_group: list_all_servers_in_group
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)

      beta =
        ServersTestHelpers.insert_server(owner.id, class.id, name: "beta", username: "user-z")

      unnamed_a =
        ServersTestHelpers.insert_server(owner.id, class.id, name: nil, username: "user-a")

      alpha =
        ServersTestHelpers.insert_server(owner.id, class.id, name: "alpha", username: "user-m")

      auth = Factory.build(:authentication, root: true)

      # `list_all_servers_in_group` returns curated `ServerView`s; the explicit
      # expected order pins the `[name, username, ip_address]` sort.
      assert list_all_servers_in_group.(auth, class.id) ==
               {:ok, Enum.map([alpha, beta, unnamed_a], &listed_server_view(&1.id))}

      assert_no_stored_events!()
    end

    test "listing servers of an unknown group returns a not-found error", %{
      list_all_servers_in_group: list_all_servers_in_group
    } do
      auth = Factory.build(:authentication, root: true)

      assert list_all_servers_in_group.(auth, Ecto.UUID.generate()) ==
               {:error, :server_group_not_found}

      assert_no_stored_events!()
    end

    test "a non-root user listing servers of a group is masked as not-found", %{
      list_all_servers_in_group: list_all_servers_in_group
    } do
      class = CourseFactory.insert(:class, now: @past)
      auth = Factory.build(:authentication, root: false)

      assert list_all_servers_in_group.(auth, class.id) == {:error, :server_group_not_found}

      assert_no_stored_events!()
    end
  end

  describe "watch_server_ids/2" do
    test "returns the current server ids and subscribes to the group's servers", %{
      watch_server_ids: watch_server_ids
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server_a = ServersTestHelpers.insert_server(owner.id, class.id)
      server_b = ServersTestHelpers.insert_server(owner.id, class.id)

      {:ok, group} = ServerGroup.fetch_server_group(class.id)
      auth = Factory.build(:authentication, root: true)

      assert {:ok, server_ids, reducer} = watch_server_ids.(auth, group)
      assert server_ids == MapSet.new([server_a.id, server_b.id])
      assert is_function(reducer, 2)

      # The use case subscribed the calling process to the group's servers
      # topic, so a published creation in this group reaches it.
      new_server =
        ServersFactory.build(:server,
          group: group,
          group_id: class.id,
          owner:
            ServersFactory.build(:server_owner,
              group_member: ServersFactory.build(:server_group_member)
            )
        )

      created_event = ServerCreated.new(new_server)
      created_reference = EventsFactory.build(:event_reference)
      :ok = PubSub.publish_server_created(created_event, created_reference)

      assert_receive {:server_created, ^created_event, ^created_reference}

      # The reducer folds broadcast events into the watched id set.
      assert reducer.(server_ids, {:server_created, created_event, created_reference}) ==
               MapSet.put(server_ids, new_server.id)

      assert reducer.(
               server_ids,
               {:server_updated, ServerUpdated.new(server_a),
                EventsFactory.build(:event_reference)}
             ) == server_ids

      assert reducer.(
               server_ids,
               {:server_deleted, ServerDeleted.new(server_a),
                EventsFactory.build(:event_reference)}
             ) ==
               MapSet.delete(server_ids, server_a.id)

      assert_no_stored_events!()
    end

    test "a non-root user cannot watch a group's server ids", %{
      watch_server_ids: watch_server_ids
    } do
      class = CourseFactory.insert(:class, now: @past)
      {:ok, group} = ServerGroup.fetch_server_group(class.id)
      auth = Factory.build(:authentication, root: false)

      assert watch_server_ids.(auth, group) == {:error, :unauthorized}

      assert_no_stored_events!()
    end
  end

  # Maps a persisted class to the `ServerGroup` view exactly as
  # `list_server_groups` returns it: scalar fields from the `classes` row, with
  # both associations left unloaded (the list query preloads neither).
  defp server_group_view(class) do
    %ServerGroup{
      __meta__: loaded(ServerGroup, "classes"),
      id: class.id,
      name: class.name,
      start_date: class.start_date,
      end_date: class.end_date,
      active: class.active,
      servers_enabled: class.servers_enabled,
      ssh_public_keys_to_install: class.teacher_ssh_public_keys,
      expected_server_properties: not_loaded(:expected_server_properties, ServerGroup),
      expected_server_properties_id: class.expected_server_properties_id,
      servers: %NotLoaded{__field__: :servers, __owner__: ServerGroup, __cardinality__: :many},
      version: class.version,
      created_at: class.created_at,
      updated_at: class.updated_at
    }
  end

  # The curated `ServerView` `list_all_servers_in_group` returns for a server,
  # projected from the same full-graph load `Server.fetch_server` performs
  # (independent of the use case).
  defp listed_server_view(id) do
    {:ok, server} = Server.fetch_server(id)
    ServerView.from(server)
  end
end
