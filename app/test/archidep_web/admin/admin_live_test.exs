defmodule ArchiDepWeb.Admin.AdminLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.PubSub.Scope
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientMock
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.UseCases.ReadServers
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.TrackerClientMock

  @path "/admin"
  @now ~U[2026-06-20 12:00:00Z]

  # The page renders the configured SSH public key verbatim (see the `servers`
  # config in `config/test.exs`).
  @ssh_public_key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1Q2L2jlt2R71iHClMbx1uIIkKbBGMwGo5c1gFJVArH archidep"

  # What this environment is: one archived edition, an edition being rendered
  # that is not it (`config/test.exs` says 1955) and nowhere configured to keep
  # the finished ones, so the page says the deployment is incomplete. The
  # sentence moves when an edition is archived, like the assertions in
  # `ArchiDep.CourseSite.ArchivesTest` do.
  @past_editions {"Edition 2025 must be served from this host, which has no archives directory",
                  :error}

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    setup do
      Hammox.stub(ArchiDep.Clock.Mock, :now, fn -> @now end)

      # `update_server_state_map/2` is a pure helper the page's state-map
      # refresher routes through the tracker client; it is replicated here so
      # the aggregate map (and the connected-server count it feeds) stays
      # intact.
      stub(ServerTrackerClientMock, :update_server_state_map, fn map,
                                                                 {:server_state, id, state} ->
        Map.put(map, id, state)
      end)

      :ok
    end

    test "renders the active classes with their servers, the ansible queue overlay and the connected-server count",
         %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha")
      beta = build_class(name: "Beta")

      web01 = build_server(alpha, created_at: ~U[2026-06-20 10:00:00Z])
      web02 = build_server(alpha, created_at: ~U[2026-06-20 11:00:00Z])
      db01 = build_server(beta, created_at: ~U[2026-06-20 10:30:00Z])

      servers_by_class_id = %{alpha.id => [web01, web02], beta.id => [db01]}
      stub_admin_page(auth, [alpha, beta], servers_by_class_id)

      # web02 has no real-time state, so it renders disconnected and is not
      # counted; web01 and db01 are connected.
      state_map = Map.new([web01, db01], &{&1.id, connected_state(&1)})

      expect_connected_mount(
        [web01, web02, db01],
        state_map,
        [
          {"queue:default", %{demand: 3, pending: 2}},
          {"playbook:run-1", %{type: :playbook}},
          {"job:abc", %{}}
        ]
      )

      {:ok, _view, html} = live(conn, @path)

      assert_html_title(html, "Admin · ArchiDep")

      assert page(html) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"2/3", :warning},
                 ansible_jobs: {"2", :warning},
                 connected_servers: {"2", :success}
               },
               classes: [
                 {"Servers for Alpha", [{web01.id, :connected}, {web02.id, :not_connected}]},
                 {"Servers for Beta", [{db01.id, :connected}]}
               ]
             }
    end

    test "renders an empty state with zeroed stats when there are no active classes", %{
      conn: conn,
      auth: auth
    } do
      stub_admin_page(auth, [], %{})
      expect_connected_mount([], %{}, [])

      {:ok, _view, html} = live(conn, @path)

      assert page(html) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: []
             }
    end

    test "adds a server to its class when it is created", %{
      conn: conn,
      auth: auth
    } do
      alpha = build_class(name: "Alpha")
      web01 = build_server(alpha, created_at: ~U[2026-06-20 10:00:00Z])
      stub_admin_page(auth, [alpha], %{alpha.id => [web01]})
      expect_connected_mount([web01], %{web01.id => connected_state(web01)}, [])

      {:ok, view, _html} = live(conn, @path)

      web02 = build_server(alpha, created_at: ~U[2026-06-20 11:00:00Z])
      web02_id = web02.id
      web02_view = ServerView.from(web02)

      stub(Servers.ContextMock, :fetch_server, fn ^auth, ^web02_id -> {:ok, web02_view} end)

      :ok =
        Servers.PubSub.publish_server_created(
          ServerCreated.new(web02),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.servers_by_class_id[alpha.id], &(&1.id == web02.id)) end,
        "created server added"
      )

      # The created server appears immediately; watching its real-time state is
      # the group tracker's own concern, so it renders disconnected until the
      # tracker pushes a state.
      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"1", :success}
               },
               classes: [
                 {"Servers for Alpha", [{web01.id, :connected}, {web02.id, :not_connected}]}
               ]
             }
    end

    test "moves a server into its newly assigned class when updated", %{
      conn: conn,
      auth: auth
    } do
      alpha = build_class(name: "Alpha")
      web01 = build_server(alpha, created_at: ~U[2026-06-20 10:00:00Z])
      stub_admin_page(auth, [alpha], %{alpha.id => [web01]})
      expect_connected_mount([web01], %{web01.id => connected_state(web01)}, [])

      {:ok, view, _html} = live(conn, @path)

      web02 = build_server(alpha, created_at: ~U[2026-06-20 11:00:00Z])
      web02_id = web02.id
      web02_view = ServerView.from(web02)

      stub(Servers.ContextMock, :fetch_server, fn ^auth, ^web02_id -> {:ok, web02_view} end)

      :ok =
        Servers.PubSub.publish_server_updated(
          ServerUpdated.new(web02),
          EventsFactory.build(:event_reference, version: web02.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.servers_by_class_id[alpha.id], &(&1.id == web02.id)) end,
        "updated server moved into class"
      )

      # The server is placed into its class immediately; its real-time state is
      # the group tracker's concern, so it renders disconnected for now.
      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"1", :success}
               },
               classes: [
                 {"Servers for Alpha", [{web01.id, :connected}, {web02.id, :not_connected}]}
               ]
             }
    end

    test "keeps an already-shown server in place when it is updated", %{
      conn: conn,
      auth: auth
    } do
      alpha = build_class(name: "Alpha")
      web01 = build_server(alpha, username: "deploy", created_at: ~U[2026-06-20 10:00:00Z])
      stub_admin_page(auth, [alpha], %{alpha.id => [web01]})
      expect_connected_mount([web01], %{web01.id => connected_state(web01)}, [])

      {:ok, view, _html} = live(conn, @path)

      # An in-place update changes only fields the list page does not surface
      # (the card shows identity and connection state), so the section is
      # unchanged.
      renamed = %{web01 | username: "renamed", version: web01.version + 1}

      :ok =
        Servers.PubSub.publish_server_updated(
          ServerUpdated.new(renamed),
          EventsFactory.build(:event_reference, version: renamed.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          Enum.any?(assigns.servers_by_class_id[alpha.id], &(&1.username == "renamed"))
        end,
        "updated server replaced in place"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"1", :success}
               },
               classes: [{"Servers for Alpha", [{web01.id, :connected}]}]
             }
    end

    test "removes a server when it is deleted", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha")
      web01 = build_server(alpha, created_at: ~U[2026-06-20 10:00:00Z])
      web02 = build_server(alpha, created_at: ~U[2026-06-20 11:00:00Z])
      stub_admin_page(auth, [alpha], %{alpha.id => [web01, web02]})

      state_map = Map.new([web01, web02], &{&1.id, connected_state(&1)})
      expect_connected_mount([web01, web02], state_map, [])

      {:ok, view, _html} = live(conn, @path)

      :ok =
        Servers.PubSub.publish_server_deleted(
          ServerDeleted.new(web02),
          EventsFactory.build(:event_reference)
        )

      # The group tracker untracks the deleted server and pushes its absent
      # state; simulate that push so the connected count drops alongside the
      # list removal the page performs.
      send(view.pid, {:server_state, web02.id, nil})

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          not Enum.any?(assigns.servers_by_class_id[alpha.id], &(&1.id == web02.id)) and
            assigns.server_state_map[web02.id] == nil
        end,
        "deleted server removed"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"1", :success}
               },
               classes: [{"Servers for Alpha", [{web01.id, :connected}]}]
             }
    end

    test "updates the connected-server count when a tracked server state changes", %{
      conn: conn,
      auth: auth
    } do
      alpha = build_class(name: "Alpha")
      web01 = build_server(alpha, created_at: ~U[2026-06-20 10:00:00Z])
      stub_admin_page(auth, [alpha], %{alpha.id => [web01]})
      expect_connected_mount([web01], %{}, [])

      {:ok, view, html} = live(conn, @path)

      assert page(html) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Alpha", [{web01.id, :not_connected}]}]
             }

      web01_state = connected_state(web01)
      send(view.pid, {:server_state, web01.id, web01_state})

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.server_state_map[web01.id] == web01_state end,
        "server state tracked"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"1", :success}
               },
               classes: [{"Servers for Alpha", [{web01.id, :connected}]}]
             }
    end

    test "tracks the ansible queue and jobs from presence diffs", %{conn: conn, auth: auth} do
      stub_admin_page(auth, [], %{})
      expect_connected_mount([], %{}, [{"queue:default", %{demand: 4, pending: 1}}])

      {:ok, view, html} = live(conn, @path)

      assert page(html) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"1/4", :warning},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: []
             }

      send(view.pid, {:update, "queue:default", %{pending: 3}})
      send(view.pid, {:join, "job:abc", %{}})

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          assigns.ansible.pending == 3 and MapSet.member?(assigns.ansible.ongoing, "job:abc")
        end,
        "queue and jobs tracked"
      )

      assert stats(render(view)) == %{
               ansible_queue: {"3/4", :warning},
               ansible_jobs: {"1", :warning},
               connected_servers: {"0", :secondary}
             }

      send(view.pid, {:leave, "queue:default", %{}})
      send(view.pid, {:leave, "job:abc", %{}})

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          assigns.ansible.pending == 0 and not MapSet.member?(assigns.ansible.ongoing, "job:abc")
        end,
        "queue and jobs cleared"
      )

      assert stats(render(view)) == %{
               ansible_queue: {"0/4", :success},
               ansible_jobs: {"0", :success},
               connected_servers: {"0", :secondary}
             }
    end

    test "adds an active class created over PubSub", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha", end_date: ~D[2026-06-30])
      stub_admin_page(auth, [alpha], %{alpha.id => []})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      beta = build_class(name: "Beta", end_date: ~D[2026-12-31])
      beta_id = beta.id

      # The created broadcast carries only the curated event; the handler
      # fetches the full view through the context boundary on first sighting.
      stub(Course.ContextMock, :fetch_class, fn ^auth, ^beta_id -> {:ok, ClassView.from(beta)} end)

      :ok =
        Course.PubSub.publish_class_created(
          ClassCreated.new(beta),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.active_classes, &(&1.id == beta.id)) end,
        "active class added"
      )

      # Classes are ordered by end date descending, so the later-dated Beta sorts
      # before Alpha.
      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Beta", []}, {"Servers for Alpha", []}]
             }
    end

    test "ignores an inactive class created over PubSub", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha", end_date: ~D[2026-06-30])
      stub_admin_page(auth, [alpha], %{alpha.id => []})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      inactive = build_class(name: "Inactive", active: false)
      gamma = build_class(name: "Gamma", end_date: ~D[2026-12-31])

      # The created broadcast carries only the curated event; the handler fetches
      # the full view through the context boundary on first sighting, for the
      # inactive class too (which it then drops).
      stub(Course.ContextMock, :fetch_class, fn ^auth, id ->
        {:ok, [inactive, gamma] |> Enum.find(&(&1.id == id)) |> ClassView.from()}
      end)

      :ok =
        Course.PubSub.publish_class_created(
          ClassCreated.new(inactive),
          EventsFactory.build(:event_reference)
        )

      # The classes topic delivers in order, so a later active class is processed
      # after the ignored inactive one; waiting for it proves the inactive class
      # was seen and dropped.
      :ok =
        Course.PubSub.publish_class_created(
          ClassCreated.new(gamma),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.active_classes, &(&1.id == gamma.id)) end,
        "later active class added"
      )

      # The ignored inactive class is absent from the whole list; classes are
      # ordered by end date descending, so the later-dated Gamma sorts before
      # Alpha.
      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Gamma", []}, {"Servers for Alpha", []}]
             }
    end

    test "renames a class in place when it is updated over PubSub", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha")
      stub_admin_page(auth, [alpha], %{alpha.id => []})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      renamed = %{alpha | name: "Renamed", version: alpha.version + 1}

      :ok =
        Course.PubSub.publish_class_updated(
          renamed,
          ClassUpdated.new(renamed),
          EventsFactory.build(:event_reference, version: renamed.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          Enum.any?(assigns.active_classes, &(&1.id == alpha.id and &1.name == "Renamed"))
        end,
        "class renamed"
      )

      # The class is renamed in place; no stale "Alpha" section lingers.
      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Renamed", []}]
             }
    end

    test "removes a class that becomes inactive on update over PubSub", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha")
      beta = build_class(name: "Beta")
      stub_admin_page(auth, [alpha, beta], %{alpha.id => [], beta.id => []})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      deactivated = %{beta | active: false, version: beta.version + 1}

      :ok =
        Course.PubSub.publish_class_updated(
          deactivated,
          ClassUpdated.new(deactivated),
          EventsFactory.build(:event_reference, version: deactivated.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.active_classes, &(&1.id == beta.id)) end,
        "deactivated class removed"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Alpha", []}]
             }
    end

    test "adds a class that becomes active on update over PubSub", %{conn: conn, auth: auth} do
      gamma = build_class(name: "Gamma")
      stub_admin_page(auth, [], %{})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      # The class is not currently active, so it is not in the list and not
      # cached; admin_live fetches the full class to add it.
      stub(Course.ContextMock, :fetch_class, fn ^auth, _id -> {:ok, ClassView.from(gamma)} end)

      :ok =
        Course.PubSub.publish_class_updated(
          gamma,
          ClassUpdated.new(gamma),
          EventsFactory.build(:event_reference, version: gamma.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.active_classes, &(&1.id == gamma.id)) end,
        "class added"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Gamma", []}]
             }
    end

    test "removes a deleted class over PubSub", %{conn: conn, auth: auth} do
      alpha = build_class(name: "Alpha")
      beta = build_class(name: "Beta")
      stub_admin_page(auth, [alpha, beta], %{alpha.id => [], beta.id => []})
      expect_connected_mount([], %{}, [])

      {:ok, view, _html} = live(conn, @path)

      :ok =
        Course.PubSub.publish_class_deleted(
          ClassDeleted.new(beta),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.active_classes, &(&1.id == beta.id)) end,
        "deleted class removed"
      )

      assert page(render(view)) == %{
               ssh_public_key: @ssh_public_key,
               past_editions: @past_editions,
               stats: %{
                 ansible_queue: {"0/0", :success},
                 ansible_jobs: {"0", :success},
                 connected_servers: {"0", :secondary}
               },
               classes: [{"Servers for Alpha", []}]
             }
    end
  end

  test "accessing the admin page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  defp build_class(overrides),
    do:
      CourseFactory.build(
        :class,
        Enum.into(overrides, %{active: true, start_date: nil, end_date: nil})
      )

  defp build_server(class, overrides),
    do:
      ServersFactory.build(
        :server,
        Enum.into(overrides, %{
          group_id: class.id,
          group: ServersFactory.build(:server_group, id: class.id, name: class.name),
          owner: ServersFactory.build(:server_owner)
        })
      )

  defp connected_state(server),
    do: real_time_state(server, ServersFactory.random_connected_state())

  defp real_time_state(server, connection_state),
    do: %ServerRealTimeState{
      connection_state: connection_state,
      name: server.name,
      conn_params: {server.ip_address.address, server.ssh_port || 22, server.username},
      username: server.username,
      app_username: server.app_username,
      current_job: nil,
      problems: [],
      version: 1
    }

  # The page reads the classes and their servers on both the disconnected and
  # connected mounts, and keeps its aggregate state map current through the
  # Servers boundary; route that call to the real read-model plumbing so a real
  # tracker push still drives the connected-server count.
  defp stub_admin_page(auth, classes, servers_by_class_id) do
    stub(Course.ContextMock, :list_active_classes, fn ^auth ->
      Enum.map(classes, &ClassView.from/1)
    end)

    stub(Servers.ContextMock, :list_all_servers_in_group, fn ^auth, group_id ->
      {:ok, servers_by_class_id |> Map.get(group_id, []) |> Enum.map(&ServerView.from/1)}
    end)

    stub(Servers.ContextMock, :refresh_server_state_map, &ReadServers.refresh_server_state_map/2)

    :ok
  end

  # The ansible-queue presence list happens once, on the connected mount only.
  # The initial server-state map is read on every mount (outside the connection
  # guard), so it is stubbed; the tracked servers reach the client in
  # `Map.values/1` order (non-deterministic), so the argument is pinned as a set
  # by sorting on the id. One self-managing group tracker is started per class;
  # each returns a real, stoppable process so the page can stop it when a class
  # is unwatched.
  defp expect_connected_mount(all_servers, state_map, ansible_entries) do
    sorted = all_servers |> Enum.map(&ServerView.from/1) |> Enum.sort_by(& &1.id)

    ansible_queue_topic = Scope.global_topic("ansible-queue")
    expect(TrackerClientMock, :list, 1, fn ^ansible_queue_topic -> ansible_entries end)

    stub(ServerTrackerClientMock, :start_link, fn _auth, _servers, {:group, _group_id} ->
      Agent.start_link(fn -> nil end)
    end)

    stub(ServerTrackerClientMock, :server_state_map, fn servers ->
      assert Enum.sort_by(servers, & &1.id) == sorted
      state_map
    end)

    :ok
  end

  defp page(html),
    do: %{
      ssh_public_key: ssh_public_key(html),
      past_editions: past_editions(html),
      stats: stats(html),
      classes: class_sections(html)
    }

  defp ssh_public_key(html) do
    [dd] = find_html_elements(html, "dl dd.font-mono")
    html_element_text(dd)
  end

  defp past_editions(html) do
    [_ssh_public_key, dd] = find_html_elements(html, "dl dd")
    {html_element_text(dd), variant(dd)}
  end

  defp stats(html) do
    [queue, jobs, connected] = find_html_elements(html, ".stats .stat")

    %{
      ansible_queue: stat_value(queue),
      ansible_jobs: stat_value(jobs),
      connected_servers: stat_value(connected)
    }
  end

  defp stat_value(stat) do
    [value] = find_html_elements(stat, ".stat-value")
    {html_element_text(value), stat_variant(value)}
  end

  defp stat_variant(value) do
    tokens = value |> html_element_attribute("class") |> String.split()

    cond do
      "text-warning" in tokens -> :warning
      "text-success" in tokens -> :success
      true -> :secondary
    end
  end

  defp variant(element) do
    tokens = element |> html_element_attribute("class") |> String.split()

    cond do
      "text-error" in tokens -> :error
      "text-success" in tokens -> :success
    end
  end

  defp class_sections(html) do
    html
    |> find_html_elements("ul.mt-4 > li")
    |> Enum.map(fn section ->
      [heading] = find_html_elements(section, "h2")
      cards = section |> find_html_elements(".card") |> Enum.map(&card/1)
      {html_element_text(heading), cards}
    end)
  end

  defp card(card), do: {card_server_id(card), card_state(card)}

  defp card_server_id(card) do
    [_match, id] =
      Regex.run(
        ~r"/admin/servers/([0-9a-fA-F-]{36})",
        html_element_attribute(card, "phx-click")
      )

    id
  end

  defp card_state(card) do
    tokens = card |> html_element_attribute("class") |> String.split()

    cond do
      "bg-success" in tokens -> :connected
      "bg-neutral" in tokens -> :not_connected
    end
  end
end
