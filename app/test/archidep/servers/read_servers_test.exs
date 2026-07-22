defmodule ArchiDep.Servers.ReadServersTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Servers.ContextMock
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientMock
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers

  # A fixed past instant for the persisted owner/group fixtures.
  @past ~U[2023-09-15 09:42:17.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{
      list_my_servers: protect({Context, :list_my_servers, 1}, Behaviour),
      fetch_server: protect({Context, :fetch_server, 2}, Behaviour),
      fetch_active_server_for_group_member:
        protect({Context, :fetch_active_server_for_group_member, 2}, Behaviour),
      subscribe_server: protect({Context, :subscribe_server, 1}, Behaviour),
      refresh_server: protect({Context, :refresh_server, 2}, Behaviour),
      subscribe_my_servers: protect({Context, :subscribe_my_servers, 1}, Behaviour),
      refresh_my_servers: protect({Context, :refresh_my_servers, 3}, Behaviour),
      refresh_server_state_map: protect({Context, :refresh_server_state_map, 2}, Behaviour),
      subscribe_active_server_for_member:
        protect({Context, :subscribe_active_server_for_member, 1}, Behaviour),
      refresh_active_server_for_member:
        protect({Context, :refresh_active_server_for_member, 4}, Behaviour)
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

      assert list_my_servers.(auth) ==
               Enum.map([alpha, beta, unnamed_a, unnamed_b], &ServerView.from/1)

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

      assert fetch_server.(auth, server.id) == {:ok, ServerView.from(server)}

      assert_no_stored_events!()
    end

    test "a root user can fetch any server", %{fetch_server: fetch_server} do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)

      root = Factory.build(:authentication, root: true)

      assert fetch_server.(root, server.id) == {:ok, ServerView.from(server)}

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

      assert fetch_active_server_for_group_member.(root, student.id) ==
               {:ok, ServerView.from(server)}

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

    test "a group member owning more than one active server is masked as not-found", %{
      fetch_active_server_for_group_member: fetch_active_server_for_group_member
    } do
      %{owner: owner, student: student, class: class} =
        ServersTestHelpers.register_group_member(@past)

      ServersTestHelpers.insert_server(owner.id, class.id, active: true)
      ServersTestHelpers.insert_server(owner.id, class.id, active: true)

      root = Factory.build(:authentication, root: true)

      assert fetch_active_server_for_group_member.(root, student.id) ==
               {:error, :server_not_found}

      assert_no_stored_events!()
    end
  end

  describe "subscribe_server/1" do
    test "subscribes the calling process to the server's topic", %{
      subscribe_server: subscribe_server
    } do
      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      %ServerView{} = view = ServerView.from(server)

      assert subscribe_server.(view) == :ok

      updated = %Server{server | name: "renamed", version: server.version + 1}
      event = ServerUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)
      :ok = PubSub.publish_server_updated(event, reference)

      assert_receive {:server_updated, ^event, ^reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_server/2" do
    test "reconciles the server from a server-updated message", %{
      refresh_server: refresh_server
    } do
      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      %ServerView{} = view = ServerView.from(server)

      updated = %Server{server | name: "renamed", version: server.version + 1}
      event = ServerUpdated.new(updated)
      reference = EventsFactory.build(:event_reference, version: updated.version)

      assert refresh_server.(view, {:server_updated, event, reference}) ==
               {:ok, ServerView.refresh!(view, event, reference)}

      assert_no_stored_events!()
    end

    test "ignores a server-updated message for another server", %{
      refresh_server: refresh_server
    } do
      %ServerView{} = view = ServersFactory.build(:server_view)

      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        other =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      event = ServerUpdated.new(%Server{other | version: other.version + 1})
      reference = EventsFactory.build(:event_reference, version: other.version + 1)

      assert refresh_server.(view, {:server_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end

    test "ignores the tracker and deletion messages it lets fall through", %{
      refresh_server: refresh_server
    } do
      %ServerView{} = view = ServersFactory.build(:server_view)

      assert refresh_server.(view, {:server_state, view.id, :busy}) == :ignore
      assert refresh_server.(view, {:server_deleted, view, :reference}) == :ignore
      assert refresh_server.(view, :unrelated) == :ignore

      assert_no_stored_events!()
    end

    test "ignores any message when there is no server to reconcile", %{
      refresh_server: refresh_server
    } do
      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      event = ServerUpdated.new(%Server{server | version: server.version + 1})
      reference = EventsFactory.build(:event_reference, version: server.version + 1)

      assert refresh_server.(nil, {:server_updated, event, reference}) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "subscribe_my_servers/1" do
    test "delivers creation, update and deletion of the principal's own servers", %{
      subscribe_my_servers: subscribe_my_servers
    } do
      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)
      auth = Factory.build(:authentication, principal_id: owner.id)

      %Server{} =
        server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      assert subscribe_my_servers.(auth) == :ok

      created = ServerCreated.new(server)
      created_reference = EventsFactory.build(:event_reference)
      :ok = PubSub.publish_server_created(created, created_reference)
      assert_receive {:server_created, ^created, ^created_reference}

      updated = ServerUpdated.new(%Server{server | version: server.version + 1})
      updated_reference = EventsFactory.build(:event_reference, version: server.version + 1)
      :ok = PubSub.publish_server_updated(updated, updated_reference)
      assert_receive {:server_updated, ^updated, ^updated_reference}

      deleted = ServerDeleted.new(server)
      deleted_reference = EventsFactory.build(:event_reference)
      :ok = PubSub.publish_server_deleted(deleted, deleted_reference)
      assert_receive {:server_deleted, ^deleted, ^deleted_reference}

      assert_no_stored_events!()
    end

    test "delivers nothing for another owner's servers", %{
      subscribe_my_servers: subscribe_my_servers
    } do
      owner = ServersFactory.build(:server_owner)
      auth = Factory.build(:authentication, principal_id: owner.id)

      assert subscribe_my_servers.(auth) == :ok

      other_group = ServersFactory.build(:server_group)
      other_owner = ServersFactory.build(:server_owner)

      %Server{} =
        other_server =
        ServersFactory.build(:server,
          group: other_group,
          group_id: other_group.id,
          owner: other_owner,
          owner_id: other_owner.id
        )

      event = ServerUpdated.new(%Server{other_server | version: other_server.version + 1})
      reference = EventsFactory.build(:event_reference, version: other_server.version + 1)
      :ok = PubSub.publish_server_updated(event, reference)

      refute_receive {:server_updated, _event, _reference}

      assert_no_stored_events!()
    end
  end

  describe "refresh_my_servers/3" do
    test "reconciles only the matching server and re-sorts the list", %{
      refresh_my_servers: refresh_my_servers
    } do
      auth = Factory.build(:authentication)
      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        target_server =
        ServersFactory.build(:server,
          name: "zzz-server",
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      %ServerView{} = target = ServerView.from(target_server)
      %ServerView{} = other = ServersFactory.build(:server_view, name: "aaa-server")

      event = ServerUpdated.new(%Server{target_server | version: target_server.version + 1})
      reference = EventsFactory.build(:event_reference, version: target_server.version + 1)

      # `other` sorts ahead of the refreshed target by name and must pass
      # through unchanged.
      assert refresh_my_servers.(auth, [target, other], {:server_updated, event, reference}) ==
               {:ok, [other, ServerView.refresh!(target, event, reference)]}

      assert_no_stored_events!()
    end

    test "fetches a newly created server and inserts it in sorted order", %{
      refresh_my_servers: refresh_my_servers
    } do
      auth = Factory.build(:authentication)
      %ServerView{} = existing = ServersFactory.build(:server_view, name: "zzz-server")

      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        created_server =
        ServersFactory.build(:server,
          name: "aaa-server",
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      %ServerView{} = created = ServerView.from(created_server)
      created_id = created.id
      reference = EventsFactory.build(:event_reference)

      # The created broadcast carries only the curated event, so the read-model
      # fetches the full view through the context boundary on first sighting.
      expect(ContextMock, :fetch_server, fn ^auth, ^created_id -> {:ok, created} end)

      assert refresh_my_servers.(
               auth,
               [existing],
               {:server_created, ServerCreated.new(created_server), reference}
             ) == {:ok, [created, existing]}

      assert_no_stored_events!()
    end

    test "keeps the list unchanged when the created server can no longer be fetched", %{
      refresh_my_servers: refresh_my_servers
    } do
      auth = Factory.build(:authentication)
      %ServerView{} = existing = ServersFactory.build(:server_view, name: "web-01")

      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        created_server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      created_id = created_server.id
      reference = EventsFactory.build(:event_reference)

      expect(ContextMock, :fetch_server, fn ^auth, ^created_id ->
        {:error, :server_not_found}
      end)

      assert refresh_my_servers.(
               auth,
               [existing],
               {:server_created, ServerCreated.new(created_server), reference}
             ) == {:ok, [existing]}

      assert_no_stored_events!()
    end

    test "removes a deleted server from the list", %{refresh_my_servers: refresh_my_servers} do
      auth = Factory.build(:authentication)
      %ServerView{} = kept = ServersFactory.build(:server_view, name: "web-01")

      group = ServersFactory.build(:server_group)
      owner = ServersFactory.build(:server_owner)

      %Server{} =
        removed_server =
        ServersFactory.build(:server,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        )

      %ServerView{} = removed = ServerView.from(removed_server)
      reference = EventsFactory.build(:event_reference)

      assert refresh_my_servers.(
               auth,
               [kept, removed],
               {:server_deleted, ServerDeleted.new(removed_server), reference}
             ) == {:ok, [kept]}

      assert_no_stored_events!()
    end

    test "ignores unrelated messages", %{refresh_my_servers: refresh_my_servers} do
      auth = Factory.build(:authentication)
      %ServerView{} = view = ServersFactory.build(:server_view)

      assert refresh_my_servers.(auth, [view], :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "refresh_server_state_map/2" do
    setup do
      # The map fold lives in the tracker client; route it to the real
      # implementation so the reconciler is exercised end to end.
      stub(
        ServerTrackerClientMock,
        :update_server_state_map,
        &ServerTracker.update_server_state_map/2
      )

      :ok
    end

    test "folds a real-time state update into the map, preserving other entries", %{
      refresh_server_state_map: refresh_server_state_map
    } do
      kept_id = Ecto.UUID.generate()
      updated_id = Ecto.UUID.generate()

      state = %ServerRealTimeState{
        connection_state: ServersFactory.random_not_connected_state(),
        name: "web-01",
        conn_params: {{1, 2, 3, 4}, 22, "root"},
        username: "root",
        app_username: "app"
      }

      assert refresh_server_state_map.(
               %{kept_id => nil},
               {:server_state, updated_id, state}
             ) == {:ok, %{kept_id => nil, updated_id => state}}

      assert_no_stored_events!()
    end

    test "ignores messages that are not real-time state updates", %{
      refresh_server_state_map: refresh_server_state_map
    } do
      assert refresh_server_state_map.(%{}, :unrelated) == :ignore

      assert_no_stored_events!()
    end
  end

  describe "subscribe_active_server_for_member/1" do
    test "delivers a linked member's server events", %{
      subscribe_active_server_for_member: subscribe_active_server_for_member
    } do
      owner = ServersFactory.build(:server_owner)

      assert subscribe_active_server_for_member.(owner.id) == :ok

      server =
        ServersFactory.build(:server,
          owner: owner,
          owner_id: owner.id,
          group: ServersFactory.build(:server_group)
        )

      created_event = ServerCreated.new(server)
      created_reference = EventsFactory.build(:event_reference)
      :ok = PubSub.publish_server_created(created_event, created_reference)

      assert_receive {:server_created, ^created_event, ^created_reference}

      assert_no_stored_events!()
    end

    test "is a no-op for an unlinked member", %{
      subscribe_active_server_for_member: subscribe_active_server_for_member
    } do
      assert subscribe_active_server_for_member.(nil) == :ok

      assert_no_stored_events!()
    end
  end

  describe "refresh_active_server_for_member/4" do
    setup do
      stub(ArchiDep.Clock.Mock, :now, fn -> @past end)
      :ok
    end

    test "merges a server update into the tracked server in memory", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {%Server{} = server, view} = active_server()

      event = ServerUpdated.new(%Server{server | name: "renamed", version: server.version + 1})
      reference = EventsFactory.build(:event_reference, version: server.version + 1)

      # No `fetch_active_server_for_group_member` is stubbed, so a passing
      # assertion proves the in-memory merge ran rather than a re-fetch (which
      # would raise an unexpected-call error).
      assert refresh_active_server_for_member.(
               auth,
               Ecto.UUID.generate(),
               view,
               {:server_updated, event, reference}
             ) == {:ok, ServerView.refresh!(view, event, reference)}

      assert_no_stored_events!()
    end

    test "drops the tracked server when an update makes it inactive", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {%Server{} = server, view} = active_server()

      event = ServerUpdated.new(%Server{server | active: false, version: server.version + 1})
      reference = EventsFactory.build(:event_reference, version: server.version + 1)

      assert refresh_active_server_for_member.(
               auth,
               Ecto.UUID.generate(),
               view,
               {:server_updated, event, reference}
             ) == {:ok, nil}

      assert_no_stored_events!()
    end

    test "fetches the member's active server on a create or first-seen update", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {server, fetched} = active_server()
      member_id = Ecto.UUID.generate()

      stub(ContextMock, :fetch_active_server_for_group_member, fn ^auth, ^member_id ->
        {:ok, fetched}
      end)

      created =
        {:server_created, ServerCreated.new(server), EventsFactory.build(:event_reference)}

      updated =
        {:server_updated, ServerUpdated.new(server), EventsFactory.build(:event_reference)}

      assert refresh_active_server_for_member.(auth, member_id, nil, created) == {:ok, fetched}
      assert refresh_active_server_for_member.(auth, member_id, nil, updated) == {:ok, fetched}

      assert_no_stored_events!()
    end

    test "re-fetches on a class update when nothing is tracked", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {_server, fetched} = active_server()
      member_id = Ecto.UUID.generate()

      stub(ContextMock, :fetch_active_server_for_group_member, fn ^auth, ^member_id ->
        {:ok, fetched}
      end)

      event = ClassUpdated.new(CourseFactory.build(:class))
      reference = EventsFactory.build(:event_reference)

      assert refresh_active_server_for_member.(
               auth,
               member_id,
               nil,
               {:class_updated, event, reference}
             ) == {:ok, fetched}

      assert_no_stored_events!()
    end

    test "drops the tracked server when it is deleted and ignores other deletions", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {server, view} = active_server()
      {other_server, _other_view} = active_server()

      deleted =
        {:server_deleted, ServerDeleted.new(server), EventsFactory.build(:event_reference)}

      other =
        {:server_deleted, ServerDeleted.new(other_server), EventsFactory.build(:event_reference)}

      assert refresh_active_server_for_member.(auth, Ecto.UUID.generate(), view, deleted) ==
               {:ok, nil}

      assert refresh_active_server_for_member.(auth, Ecto.UUID.generate(), view, other) == :ignore

      assert_no_stored_events!()
    end

    test "ignores messages it does not handle", %{
      refresh_active_server_for_member: refresh_active_server_for_member
    } do
      auth = Factory.build(:authentication)
      {_server, view} = active_server()

      assert refresh_active_server_for_member.(auth, Ecto.UUID.generate(), view, :unrelated) ==
               :ignore

      assert refresh_active_server_for_member.(
               auth,
               Ecto.UUID.generate(),
               view,
               {:preregistered_user_updated, %{}, EventsFactory.build(:event_reference)}
             ) == :ignore

      assert_no_stored_events!()
    end
  end

  # A server that is unconditionally active at any instant (a root, active,
  # group-member-less owner and a window-less active group) paired with its
  # view, so the refresher's `ServerView.active?` checks are deterministic.
  defp active_server do
    server =
      ServersFactory.build(:server,
        active: true,
        group: ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil),
        owner: ServersFactory.build(:server_owner, root: true, active: true, group_member: nil)
      )

    {server, ServerView.from(server)}
  end
end
