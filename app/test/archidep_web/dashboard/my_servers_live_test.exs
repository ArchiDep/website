defmodule ArchiDepWeb.Dashboard.MyServersLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientMock
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  describe "the my servers page" do
    setup :register_and_log_in_student

    test "renders a card for each of my servers", %{conn: conn, auth: auth} do
      web = ServersFactory.build(:server, name: "web-01", active: true)
      db = ServersFactory.build(:server, name: "db-01", active: true)
      stub_page(auth, [web, db])

      {:ok, _view, html} = live(conn, "/app/my-servers")

      assert server_cards(html) == %{
               "/servers/#{web.id}" => %{name: "web-01", badge: "Not connected"},
               "/servers/#{db.id}" => %{name: "db-01", badge: "Not connected"}
             }
    end

    test "renders the empty state when I have no servers", %{conn: conn, auth: auth} do
      stub_page(auth, [])

      {:ok, _view, html} = live(conn, "/app/my-servers")

      assert server_cards(html) == %{}
      assert html =~ gettext("You have not registered any server yet.")
    end

    test "retrying a connection delegates to the context", %{conn: conn, auth: auth} do
      server = ServersFactory.build(:server, name: "web-01", active: true)
      stub_page(auth, [server])
      server_id = server.id

      expect(Servers.ContextMock, :retry_connecting, fn ^auth, ^server_id -> :ok end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      render_hook(view, "retry_connecting", %{"server_id" => server.id})

      assert flash_notifications(view) == []
    end
  end

  describe "live updates" do
    setup :register_and_log_in_student

    test "reflects a server's real-time state update", %{conn: conn, auth: auth} do
      server = ServersFactory.build(:server, name: "web-01", active: true)
      stub_page(auth, [server])
      server_id = server.id

      state = real_time_state(server, connection_state: ServersFactory.random_connected_state())

      expect(ServerTrackerClientMock, :update_server_state_map, fn %{},
                                                                   {:server_state, ^server_id,
                                                                    ^state} ->
        %{server_id => state}
      end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      send(view.pid, {:server_state, server.id, state})

      wait_for_socket_assigns!(
        view,
        fn assigns -> Map.has_key?(assigns.server_state_map, server_id) end,
        "server state updated"
      )

      assert server_cards(render(view)) == %{
               "/servers/#{server.id}" => %{name: "web-01", badge: "Connected"}
             }
    end

    test "adds a newly created server I own", %{conn: conn, auth: auth} do
      existing = ServersFactory.build(:server, name: "web-01", active: true)
      stub_page(auth, [existing])

      created =
        ServersFactory.build(:server, name: "web-02", active: true, owner_id: auth.principal_id)

      created_id = created.id

      created_state =
        real_time_state(created, connection_state: ServersFactory.random_connected_state())

      update = {:server_state, created_id, created_state}

      expect(ServerTrackerClientMock, :track, fn _tracker, ^created -> update end)

      expect(ServerTrackerClientMock, :update_server_state_map, fn %{}, ^update ->
        %{created_id => created_state}
      end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      :ok = PubSub.publish_server_created(created)

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.servers, &(&1.id == created_id)) end,
        "server created"
      )

      assert server_cards(render(view)) == %{
               "/servers/#{existing.id}" => %{name: "web-01", badge: "Not connected"},
               "/servers/#{created.id}" => %{name: "web-02", badge: "Connected"}
             }
    end

    test "ignores a created server I do not own", %{conn: conn, auth: auth} do
      existing = ServersFactory.build(:server, name: "web-01", active: true)
      stub_page(auth, [existing])

      unrelated =
        ServersFactory.build(:server, name: "other-01", active: true, owner_id: UUID.generate())

      {:ok, view, _html} = live(conn, "/app/my-servers")

      :ok = PubSub.publish_server_created(unrelated)

      assert server_cards(render(view)) == %{
               "/servers/#{existing.id}" => %{name: "web-01", badge: "Not connected"}
             }
    end

    test "reflects a server name update", %{conn: conn, auth: auth} do
      server =
        ServersFactory.build(:server,
          name: "web-01",
          active: true,
          owner: build_owner(),
          group: ServersFactory.build(:server_group)
        )

      stub_page(auth, [server])
      server_id = server.id

      {:ok, view, _html} = live(conn, "/app/my-servers")

      renamed = %{server | name: "web-renamed", version: server.version + 1}

      :ok =
        PubSub.publish_server_updated(
          ServerUpdated.new(renamed),
          EventsFactory.build(:event_reference, version: renamed.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          Enum.any?(assigns.servers, &(&1.id == server_id and &1.name == "web-renamed"))
        end,
        "server renamed"
      )

      assert server_cards(render(view)) == %{
               "/servers/#{server.id}" => %{name: "web-renamed", badge: "Not connected"}
             }
    end

    test "removes a deleted server", %{conn: conn, auth: auth} do
      web = ServersFactory.build(:server, name: "web-01", active: true)
      db = ServersFactory.build(:server, name: "db-01", active: true)
      stub_page(auth, [web, db])
      db_id = db.id

      expect(ServerTrackerClientMock, :untrack, fn _tracker, ^db ->
        {:server_state, db_id, nil}
      end)

      expect(ServerTrackerClientMock, :update_server_state_map, fn %{},
                                                                   {:server_state, ^db_id, nil} ->
        %{}
      end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      :ok = PubSub.publish_server_deleted(db)

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.servers, &(&1.id == db_id)) end,
        "server deleted"
      )

      assert server_cards(render(view)) == %{
               "/servers/#{web.id}" => %{name: "web-01", badge: "Not connected"}
             }
    end
  end

  describe "the new server dialog" do
    setup :register_and_log_in_student

    test "creates a server from a full submission", %{conn: conn, auth: auth} do
      owner = build_owner()
      stub_page(auth, [], owner)
      group_id = owner.group_member.group_id

      created = ServersFactory.build(:server, name: "web-1", owner_id: auth.principal_id)
      test_pid = self()

      expect(Servers.ContextMock, :create_server, fn ^auth, ^group_id, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      view
      |> form("#new-server-form", server: student_server_params())
      |> render_submit()

      assert_receive {:created_with, data}

      assert data == %{
               name: "web-1",
               ip_address: "192.168.1.20",
               username: "deploy",
               ssh_port: 2222,
               ssh_host_key_fingerprints: "fp-full",
               active: false,
               app_username: "archidep",
               expected_properties: %{}
             }

      assert_push_event(view, "execute-action", %{to: "#new-server-dialog", action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Registered server {server}", server: "web-1")
      )
    end

    test "renders errors when the server cannot be created", %{conn: conn, auth: auth} do
      owner = build_owner()
      stub_page(auth, [], owner)
      group_id = owner.group_member.group_id

      {:error, errored} =
        %Server{}
        |> Changeset.cast(%{"name" => "web-1"}, [:name])
        |> Changeset.add_error(:name, "has already been taken")
        |> Changeset.apply_action(:insert)

      expect(Servers.ContextMock, :create_server, fn ^auth, ^group_id, _data ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      assert view
             |> form("#new-server-form", server: student_server_params())
             |> render_submit()
             |> form_errors("new-server-form") == ["has already been taken"]

      assert_flash_notification(view, :error, gettext("The form is invalid."))

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "validates the new server against the context", %{conn: conn, auth: auth} do
      owner = build_owner()
      stub_page(auth, [], owner)
      group_id = owner.group_member.group_id

      invalid =
        %Server{}
        |> Changeset.cast(%{"username" => "deploy"}, [:username])
        |> Changeset.add_error(:username, "is invalid")

      valid = Changeset.cast(%Server{}, %{"username" => "deploy"}, [:username])

      expect(Servers.ContextMock, :validate_server, fn ^auth, ^group_id, _data ->
        {:ok, invalid}
      end)

      expect(Servers.ContextMock, :validate_server, fn ^auth, ^group_id, _data -> {:ok, valid} end)

      {:ok, view, _html} = live(conn, "/app/my-servers")

      assert view
             |> form("#new-server-form", server: student_server_params())
             |> render_change()
             |> form_errors("new-server-form") == ["is invalid"]

      assert view
             |> form("#new-server-form", server: student_server_params())
             |> render_change()
             |> form_errors("new-server-form") == []
    end
  end

  describe "as a root user" do
    setup :register_and_log_in_root

    test "lists every group's servers with the group selector available", %{
      conn: conn,
      auth: auth
    } do
      group = ServersFactory.build(:server_group, name: "Crypto 101")
      server = ServersFactory.build(:server, name: "web-01", active: true)
      stub_page(auth, [server], build_owner(root: true), groups: [group])

      {:ok, _view, html} = live(conn, "/app/my-servers")

      assert server_cards(html) == %{
               "/servers/#{server.id}" => %{name: "web-01", badge: "Not connected"}
             }

      assert html =~ "Crypto 101"
    end
  end

  test "accessing the page redirects to the login page without authentication", %{conn: conn} do
    assert_live_anonymous_user_redirected_to_login(conn, "/app/my-servers")
  end

  # The page reads the server list, the tracker state map and (through the
  # always-rendered new-server dialog) the authenticated owner on both the
  # disconnected and connected mounts, so these ambient reads are stubbed and
  # each test `expect`s only the mutation it asserts. The tracker returns an
  # empty state map, which renders every card in its initial "not connected"
  # shape. `list_server_groups` is requested only for a root caller.
  defp stub_page(auth, servers, owner \\ nil, opts \\ []) do
    stub(Course.ContextMock, :fetch_authenticated_student, fn ^auth ->
      {:error, :not_a_student}
    end)

    stub(Servers.ContextMock, :list_my_servers, fn ^auth -> servers end)

    stub(Servers.ContextMock, :fetch_authenticated_server_owner, fn ^auth ->
      owner || build_owner()
    end)

    stub(ServerTrackerClientMock, :start_link, fn _servers -> {:ok, self()} end)
    stub(ServerTrackerClientMock, :server_state_map, fn _servers -> %{} end)

    case Keyword.fetch(opts, :groups) do
      {:ok, groups} -> stub(Servers.ContextMock, :list_server_groups, fn ^auth -> groups end)
      :error -> :ok
    end

    :ok
  end

  defp build_owner(opts \\ []) do
    root = Keyword.get(opts, :root, false)

    group_member =
      if root, do: nil, else: ServersFactory.build(:server_group_member)

    ServersFactory.build(:server_owner, root: root, group_member: group_member)
  end

  defp real_time_state(server, opts),
    do: %ServerRealTimeState{
      connection_state:
        Keyword.get_lazy(opts, :connection_state, &ServersFactory.random_not_connected_state/0),
      name: server.name,
      conn_params: {server.ip_address.address, server.ssh_port || 22, server.username},
      username: server.username,
      app_username: server.app_username,
      current_job: nil,
      problems: [],
      version: 1
    }

  # Form parameters covering the fields a student sees (the form omits the
  # root-only app_username, expected properties and group selector). A
  # submission with these reaches the context; group_id is supplied by the
  # authenticated owner's group membership rather than the form.
  defp student_server_params,
    do: %{
      name: "web-1",
      ip_address: "192.168.1.20",
      username: "deploy",
      ssh_port: "2222",
      ssh_host_key_fingerprints: "fp-full",
      active: "false"
    }

  # Projects the server grid to a map keyed by each card's details link, holding
  # the displayed server name and its real-time status badge.
  defp server_cards(html) do
    html
    |> find_html_elements(".grid .card")
    |> Map.new(fn card ->
      [link | _rest] = find_html_elements(card, "a[href^='/servers/']")
      [name_element | _badge] = find_html_elements(card, ".card-title > div")
      [badge_element | _rest] = find_html_elements(card, ".card-title .badge")

      {html_element_attribute(link, "href"),
       %{
         name: card_text(name_element),
         badge: card_text(badge_element)
       }}
    end)
  end

  defp card_text(element), do: element |> html_element_text() |> String.trim()

  defp form_errors(html, form_id),
    do:
      html
      |> find_html_elements("##{form_id} p.text-error")
      |> Enum.map(&html_element_text/1)
end
