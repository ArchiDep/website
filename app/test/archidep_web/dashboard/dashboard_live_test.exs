defmodule ArchiDepWeb.Dashboard.DashboardLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientMock
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  @path "/app"
  @now ~U[2026-06-27 12:00:00Z]

  # A fixed fingerprint pair (one SHA256, one MD5) whose parsed human form is
  # deterministic, so the rendered fingerprint list can be pinned exactly.
  @sha256_fingerprint "256 SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU root@server (ED25519)"
  @md5_fingerprint "256 MD5:6d:2a:79:40:f7:cf:06:03:da:da:6f:58:dd:46:e2:bf root@server (ECDSA)"

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "the welcome screen" do
    setup :register_and_log_in_student

    test "shows the exercise connection details and host key fingerprints", %{
      conn: conn,
      auth: auth
    } do
      class =
        CourseFactory.build(:class,
          now: @now,
          active: true,
          servers_enabled: false,
          ssh_exercise_vm_sha256_host_key_fingerprints: @sha256_fingerprint,
          ssh_exercise_vm_md5_host_key_fingerprints: @md5_fingerprint
        )

      student =
        build_student(class,
          active: true,
          servers_enabled: false,
          username: "alice",
          ssh_exercise_password: "hunter2"
        )

      stub_page(auth, student: student)

      {:ok, _view, html} = live(conn, @path)

      assert_html_title(html, "Dashboard · ArchiDep")

      assert dashboard(html) == %{
               welcome: %{
                 username: "alice",
                 password: "hunter2",
                 fingerprints: [
                   "SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU (ED25519)",
                   "MD5:6d:2a:79:40:f7:cf:06:03:da:da:6f:58:dd:46:e2:bf (ECDSA)"
                 ]
               },
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{}
             }
    end

    test "omits the host key fingerprints when the class declares none", %{
      conn: conn,
      auth: auth
    } do
      class =
        CourseFactory.build(:class,
          now: @now,
          active: true,
          servers_enabled: false,
          ssh_exercise_vm_sha256_host_key_fingerprints: nil,
          ssh_exercise_vm_md5_host_key_fingerprints: nil
        )

      student =
        build_student(class,
          active: true,
          servers_enabled: false,
          username: "bob",
          ssh_exercise_password: "s3cret"
        )

      stub_page(auth, student: student)

      {:ok, _view, html} = live(conn, @path)

      assert dashboard(html) == %{
               welcome: %{username: "bob", password: "s3cret", fingerprints: []},
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{}
             }
    end
  end

  describe "the what-is-your-name prompt" do
    setup :register_and_log_in_student

    test "renders only the name prompt", %{conn: conn, auth: auth} do
      stub_page(auth, student: build_creating_student(username_confirmed: false))

      {:ok, _view, html} = live(conn, @path)

      assert dashboard(html) == %{
               welcome: nil,
               name_prompt?: true,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{}
             }
    end

    test "validates the chosen username against the context", %{conn: conn, auth: auth} do
      student = build_creating_student(username_confirmed: false)
      stub_page(auth, student: student)
      student_id = student.id

      invalid =
        %Student{}
        |> Changeset.cast(%{"username" => "bad"}, [:username])
        |> Changeset.add_error(:username, "is invalid")

      expect(Course.ContextMock, :validate_student_config, fn ^auth, ^student_id, _data ->
        {:ok, invalid}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("#what-is-your-name form", student_config: %{username: "bad"})
             |> render_change()
             |> form_errors("what-is-your-name") == ["is invalid"]
    end

    test "configures the student from a submission", %{conn: conn, auth: auth} do
      student = build_creating_student(username_confirmed: false)
      stub_page(auth, student: student)
      student_id = student.id

      configured = %{student | username: "bob"}
      test_pid = self()

      expect(Course.ContextMock, :configure_student, fn ^auth, ^student_id, data ->
        send(test_pid, {:configured_with, data})
        {:ok, configured}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#what-is-your-name form", student_config: %{username: "bob"})
      |> render_submit()

      assert_receive {:configured_with, data}
      assert data == %{username: "bob"}

      assert_flash_notification(view, :success, gettext("Hello, {name}!", name: "bob"))
    end
  end

  describe "before registering a server" do
    setup :register_and_log_in_student

    test "renders the student call to action and the change-username dialog", %{
      conn: conn,
      auth: auth
    } do
      stub_page(auth, student: build_creating_student(username_confirmed: true))

      {:ok, _view, html} = live(conn, @path)

      assert dashboard(html) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: :student,
               change_username_dialog?: true,
               servers: %{}
             }
    end

    test "registers a server from a full submission", %{conn: conn, auth: auth} do
      owner = build_owner()
      stub_page(auth, student: build_creating_student(username_confirmed: true), owner: owner)
      group_id = owner.group_member.group_id

      created = ServersFactory.build(:server, name: "api-7", owner_id: auth.principal_id)
      test_pid = self()

      expect(Servers.ContextMock, :create_server, fn ^auth, ^group_id, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#new-server-form",
        server: %{
          name: "api-7",
          ip_address: "10.0.0.7",
          username: "operator",
          ssh_port: "2200",
          ssh_host_key_fingerprints: "fp-api",
          active: "false"
        }
      )
      |> render_submit()

      assert_receive {:created_with, data}

      assert data == %{
               name: "api-7",
               ip_address: "10.0.0.7",
               username: "operator",
               ssh_port: 2200,
               ssh_host_key_fingerprints: "fp-api",
               active: false,
               app_username: "archidep",
               expected_properties: %{}
             }

      assert_push_event(view, "execute-action", %{to: "#new-server-dialog", action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Registered server {server}", server: "api-7")
      )
    end

    test "renders errors when the server cannot be created", %{conn: conn, auth: auth} do
      owner = build_owner()
      stub_page(auth, student: build_creating_student(username_confirmed: true), owner: owner)
      group_id = owner.group_member.group_id

      {:error, errored} =
        %Server{}
        |> Changeset.cast(%{"name" => "db-3"}, [:name])
        |> Changeset.add_error(:name, "has already been taken")
        |> Changeset.apply_action(:insert)

      expect(Servers.ContextMock, :create_server, fn ^auth, ^group_id, _data ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("#new-server-form",
               server: %{
                 name: "db-3",
                 ip_address: "10.0.0.3",
                 username: "dba",
                 ssh_port: "22",
                 ssh_host_key_fingerprints: "fp-db",
                 active: "false"
               }
             )
             |> render_submit()
             |> form_errors("new-server-form") == ["has already been taken"]

      assert_flash_notification(view, :error, gettext("The form is invalid."))
      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "changes the username from the change-username dialog", %{conn: conn, auth: auth} do
      student = build_creating_student(username_confirmed: true)
      stub_page(auth, student: student)
      student_id = student.id

      configured = %{student | username: "renamed"}
      test_pid = self()

      expect(Course.ContextMock, :configure_student, fn ^auth, ^student_id, data ->
        send(test_pid, {:configured_with, data})
        {:ok, configured}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#change-username-dialog form[phx-submit='configure']",
        student_config: %{username: "renamed"}
      )
      |> render_submit()

      assert_receive {:configured_with, data}
      assert data == %{username: "renamed"}

      assert_push_event(view, "execute-action", %{
        to: "#change-username-dialog",
        action: "close"
      })

      assert_flash_notification(
        view,
        :success,
        gettext("Username changed to {name}", name: "renamed")
      )
    end
  end

  describe "with a registered server" do
    setup :register_and_log_in_student

    test "renders a card for the server and nothing else", %{conn: conn, auth: auth} do
      server = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [server])

      {:ok, _view, html} = live(conn, @path)

      assert dashboard(html) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{"/servers/#{server.id}" => %{name: "web-01", badge: "Not connected"}}
             }
    end

    test "updates the server from the edit dialog", %{conn: conn, auth: auth} do
      properties = ServersFactory.build(:server_properties, cpus: nil, cores: nil)

      server =
        build_dashboard_server(auth,
          name: "web-01",
          set_up_at: nil,
          app_username: "appdeploy",
          expected_properties: properties
        )

      state =
        real_time_state(server, problems: [ServersFactory.server_connection_refused_problem()])

      stub_page(auth,
        student: build_creating_student(),
        servers: [server],
        server_state_map: %{server.id => state}
      )

      server_id = server.id
      updated = %{server | name: "web-renamed"}
      test_pid = self()

      expect(Servers.ContextMock, :update_server, fn ^auth, ^server_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated, EventsFactory.build(:event_reference)}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> form("#edit-server-form",
        server: %{
          name: "web-renamed",
          ip_address: "172.16.0.4",
          username: "maintainer",
          ssh_port: "2020",
          ssh_host_key_fingerprints: "fp-edit",
          active: "false"
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "web-renamed",
               ip_address: "172.16.0.4",
               username: "maintainer",
               ssh_port: 2020,
               ssh_host_key_fingerprints: "fp-edit",
               active: false,
               app_username: "appdeploy",
               expected_properties: %{
                 cpus: nil,
                 cores: nil,
                 vcpus: properties.vcpus,
                 memory: properties.memory,
                 swap: properties.swap,
                 system: properties.system,
                 architecture: properties.architecture,
                 os_family: properties.os_family,
                 distribution: properties.distribution,
                 distribution_release: properties.distribution_release,
                 distribution_version: properties.distribution_version
               }
             }

      dialog_id = "#edit-server-dialog-#{server.id}"
      assert_push_event(view, "execute-action", %{to: ^dialog_id, action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Updated server {server}", server: "web-renamed")
      )
    end
  end

  # The page subscribes to each server both on its per-server topic and on the
  # owner's servers topic, so a broadcast about an owned server can reach the
  # view more than once. These tests publish real broadcasts (the production
  # path) and stub the tracker so the redundant deliveries are tolerated; the
  # assertions pin the resulting page, which converges regardless of the
  # delivery count. Real-time state updates arrive directly from the tracker
  # process, so they are sent.
  describe "live updates" do
    setup :register_and_log_in_student

    test "reflects a server's real-time state update", %{conn: conn, auth: auth} do
      server = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [server])
      server_id = server.id

      state = real_time_state(server, connection_state: ServersFactory.random_connected_state())

      expect(ServerTrackerClientMock, :update_server_state_map, fn %{},
                                                                   {:server_state, ^server_id,
                                                                    ^state} ->
        %{server_id => state}
      end)

      {:ok, view, _html} = live(conn, @path)

      send(view.pid, {:server_state, server_id, state})

      wait_for_socket_assigns!(
        view,
        fn assigns -> Map.has_key?(assigns.server_state_map, server_id) end,
        "server state updated"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{"/servers/#{server.id}" => %{name: "web-01", badge: "Connected"}}
             }
    end

    test "adds a newly created active server I own", %{conn: conn, auth: auth} do
      existing = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [existing])
      stub_tracker_updates()

      created = build_dashboard_server(auth, name: "web-02", active: true)
      created_id = created.id

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_created(created)

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.servers, &(&1.id == created_id)) end,
        "server created"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{
                 "/servers/#{existing.id}" => %{name: "web-01", badge: "Not connected"},
                 "/servers/#{created.id}" => %{name: "web-02", badge: "Not connected"}
               }
             }
    end

    test "tracks a created inactive server without adding a card", %{conn: conn, auth: auth} do
      existing = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [existing])

      inactive = build_dashboard_server(auth, name: "web-02", active: false)

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_created(inactive)

      wait_for_socket_assigns!(
        view,
        fn assigns -> MapSet.member?(assigns.inactive_servers, inactive.id) end,
        "inactive server tracked"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{"/servers/#{existing.id}" => %{name: "web-01", badge: "Not connected"}}
             }
    end

    test "reflects an updated server name", %{conn: conn, auth: auth} do
      server = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [server])
      stub_tracker_updates()
      server_id = server.id

      {:ok, view, _html} = live(conn, @path)

      :ok =
        PubSub.publish_server_updated(%{
          server
          | name: "web-renamed",
            version: server.version + 1
        })

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          Enum.any?(assigns.servers, &(&1.id == server_id and &1.name == "web-renamed"))
        end,
        "server renamed"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{
                 "/servers/#{server.id}" => %{name: "web-renamed", badge: "Not connected"}
               }
             }
    end

    test "adds a server that becomes active", %{conn: conn, auth: auth} do
      active = build_dashboard_server(auth, name: "web-01")
      inactive = build_dashboard_server(auth, name: "web-02", active: false)
      stub_page(auth, student: build_creating_student(), servers: [active, inactive])
      stub_tracker_updates()

      activated = %{inactive | active: true, version: inactive.version + 1}
      activated_id = activated.id

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_updated(activated)

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.servers, &(&1.id == activated_id)) end,
        "server activated"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{
                 "/servers/#{active.id}" => %{name: "web-01", badge: "Not connected"},
                 "/servers/#{activated.id}" => %{name: "web-02", badge: "Not connected"}
               }
             }
    end

    test "removes a server that becomes inactive", %{conn: conn, auth: auth} do
      web = build_dashboard_server(auth, name: "web-01")
      db = build_dashboard_server(auth, name: "db-01")
      stub_page(auth, student: build_creating_student(), servers: [web, db])
      stub_tracker_updates()
      db_id = db.id

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_updated(%{db | active: false, version: db.version + 1})

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.servers, &(&1.id == db_id)) end,
        "server deactivated"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{"/servers/#{web.id}" => %{name: "web-01", badge: "Not connected"}}
             }
    end

    test "removes a deleted server", %{conn: conn, auth: auth} do
      web = build_dashboard_server(auth, name: "web-01")
      db = build_dashboard_server(auth, name: "db-01")
      stub_page(auth, student: build_creating_student(), servers: [web, db])
      stub_tracker_updates()
      db_id = db.id

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_deleted(db)

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.servers, &(&1.id == db_id)) end,
        "server deleted"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{"/servers/#{web.id}" => %{name: "web-01", badge: "Not connected"}}
             }
    end

    test "brings back the call to action when the last server is deleted", %{
      conn: conn,
      auth: auth
    } do
      server = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [server])
      stub_tracker_updates()

      {:ok, view, _html} = live(conn, @path)

      :ok = PubSub.publish_server_deleted(server)

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.servers == [] end,
        "last server deleted"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: :student,
               change_username_dialog?: true,
               servers: %{}
             }
    end

    test "retrying a connection delegates to the context", %{conn: conn, auth: auth} do
      server = build_dashboard_server(auth, name: "web-01")
      stub_page(auth, student: build_creating_student(), servers: [server])
      server_id = server.id

      expect(Servers.ContextMock, :retry_connecting, fn ^auth, ^server_id -> :ok end)

      {:ok, view, _html} = live(conn, @path)

      render_hook(view, "retry_connecting", %{"server_id" => server.id})

      assert flash_notifications(view) == []
    end

    test "refreshes the welcome details when the student is updated", %{conn: conn, auth: auth} do
      student = build_welcome_student(username: "alice")
      stub_page(auth, student: student)

      {:ok, view, _html} = live(conn, @path)

      :ok =
        Course.PubSub.publish_student_updated(%{
          student
          | username: "zoe",
            version: student.version + 1
        })

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.student.username == "zoe" end,
        "student renamed"
      )

      assert dashboard(render(view)) == %{
               welcome: %{username: "zoe", password: "ssh-pw", fingerprints: []},
               name_prompt?: false,
               call_to_action: nil,
               change_username_dialog?: false,
               servers: %{}
             }
    end

    test "shows the call to action when the class enables server creation", %{
      conn: conn,
      auth: auth
    } do
      student = build_welcome_student(username_confirmed: true)
      stub_page(auth, student: student)

      {:ok, view, _html} = live(conn, @path)

      updated_class = %{student.class | servers_enabled: true}

      :ok =
        Course.PubSub.publish_class_updated(
          updated_class,
          ClassUpdated.new(updated_class),
          EventsFactory.build(:event_reference, version: student.class.version + 1)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.student.class.servers_enabled end,
        "class enabled server creation"
      )

      assert dashboard(render(view)) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: :student,
               change_username_dialog?: true,
               servers: %{}
             }
    end

    test "drops the student when the class is deleted", %{conn: conn, auth: auth} do
      student = build_welcome_student(username: "alice")
      stub_page(auth, student: student)

      {:ok, view, _html} = live(conn, @path)

      :ok = Course.PubSub.publish_class_deleted(student.class)

      wait_for_socket_assigns!(view, fn assigns -> assigns.student == nil end, "student dropped")

      assert dashboard(render(view)) == empty_dashboard()
    end

    test "drops the student when the student is deleted", %{conn: conn, auth: auth} do
      student = build_welcome_student(username: "alice")
      stub_page(auth, student: student)

      {:ok, view, _html} = live(conn, @path)

      :ok = Course.PubSub.publish_student_deleted(student)

      wait_for_socket_assigns!(view, fn assigns -> assigns.student == nil end, "student dropped")

      assert dashboard(render(view)) == empty_dashboard()
    end
  end

  describe "as a root user" do
    setup :register_and_log_in_root

    test "renders the root call to action with no servers", %{conn: conn, auth: auth} do
      group = ServersFactory.build(:server_group, name: "Crypto 101")
      stub_page(auth, owner: build_owner(root: true), groups: [group])

      {:ok, _view, html} = live(conn, @path)

      assert_html_title(html, "Dashboard · ArchiDep")

      assert dashboard(html) == %{
               welcome: nil,
               name_prompt?: false,
               call_to_action: :root,
               change_username_dialog?: false,
               servers: %{}
             }
    end
  end

  test "accessing the page redirects to the login page without authentication", %{conn: conn} do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  # The page reads the student, the server list, the tracker state map and
  # (through the always-rendered new-server dialog) the authenticated owner on
  # both the disconnected and connected mounts, so these ambient reads are
  # stubbed and each test `expect`s only the mutation it asserts. The tracker
  # returns the given state map (empty by default, rendering every card in its
  # initial "not connected" shape). `list_server_groups` is requested only for a
  # root caller; `fetch_authenticated_student` only for a non-root caller.
  defp stub_page(auth, opts) do
    servers = Keyword.get(opts, :servers, [])
    server_state_map = Keyword.get(opts, :server_state_map, %{})

    case Keyword.fetch(opts, :student) do
      {:ok, student} ->
        stub(Course.ContextMock, :fetch_authenticated_student, fn ^auth -> {:ok, student} end)

      :error ->
        :ok
    end

    stub(Servers.ContextMock, :list_my_servers, fn ^auth -> servers end)

    stub(Servers.ContextMock, :fetch_authenticated_server_owner, fn ^auth ->
      Keyword.get_lazy(opts, :owner, fn -> build_owner() end)
    end)

    stub(ServerTrackerClientMock, :start_link, fn _servers -> {:ok, self()} end)
    stub(ServerTrackerClientMock, :server_state_map, fn _servers -> server_state_map end)

    case Keyword.fetch(opts, :groups) do
      {:ok, groups} -> stub(Servers.ContextMock, :list_server_groups, fn ^auth -> groups end)
      :error -> :ok
    end

    :ok
  end

  # Lets the tracker tolerate the redundant deliveries an owned server's
  # create/update/delete broadcast produces, keeping every state empty so cards
  # render in their "not connected" shape.
  defp stub_tracker_updates do
    stub(ServerTrackerClientMock, :track, fn _tracker, server ->
      {:server_state, server.id, nil}
    end)

    stub(ServerTrackerClientMock, :untrack, fn _tracker, server ->
      {:server_state, server.id, nil}
    end)

    stub(ServerTrackerClientMock, :update_server_state_map, fn map, {:server_state, id, nil} ->
      Map.delete(map, id)
    end)
  end

  defp build_student(class, opts),
    do:
      CourseFactory.build(
        :student,
        Keyword.merge([class: class, class_id: class.id, username_confirmed: true], opts)
      )

  defp build_creating_student(opts \\ []) do
    class = CourseFactory.build(:class, now: @now, active: true, servers_enabled: true)

    build_student(
      class,
      Keyword.merge([active: true, servers_enabled: true, username_confirmed: true], opts)
    )
  end

  defp build_welcome_student(opts) do
    class =
      CourseFactory.build(:class,
        now: @now,
        active: true,
        servers_enabled: false,
        ssh_exercise_vm_sha256_host_key_fingerprints: nil,
        ssh_exercise_vm_md5_host_key_fingerprints: nil
      )

    build_student(
      class,
      Keyword.merge(
        [
          active: true,
          servers_enabled: false,
          ssh_exercise_password: "ssh-pw",
          user: CourseFactory.build(:user)
        ],
        opts
      )
    )
  end

  defp build_dashboard_server(auth, opts),
    do:
      ServersFactory.build(
        :server,
        Keyword.merge(
          [active: true, owner_id: auth.principal_id, owner: build_owner(), set_up_at: nil],
          opts
        )
      )

  defp build_owner(opts \\ []) do
    root = Keyword.get(opts, :root, false)
    group_member = if root, do: nil, else: ServersFactory.build(:server_group_member)
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
      problems: Keyword.get(opts, :problems, []),
      version: 1
    }

  defp empty_dashboard,
    do: %{
      welcome: nil,
      name_prompt?: false,
      call_to_action: nil,
      change_username_dialog?: false,
      servers: %{}
    }

  # Projects the meaningful, mutually-exclusive regions of the page so each test
  # pins the whole page state — a region that should not render must be absent.
  defp dashboard(html),
    do: %{
      welcome: welcome(html),
      name_prompt?: shown?(html, "#what-is-your-name"),
      call_to_action: call_to_action(html),
      change_username_dialog?: shown?(html, "#change-username-dialog"),
      servers: server_cards(html)
    }

  defp welcome(html) do
    case find_html_elements(html, "#student-ssh-exercise-password-copy") do
      [] ->
        nil

      [copy | _rest] ->
        %{
          username: dd_value(html, gettext("Username")),
          password: html_element_attribute(copy, "data-clipboard-text"),
          fingerprints: html |> find_html_elements("li.text-xs") |> Enum.map(&normalized_text/1)
        }
    end
  end

  defp call_to_action(html) do
    cond do
      gettext("Let's get started!") not in headings(html) ->
        nil

      gettext("You are root. Register as many servers as you like.") in paragraphs(html) ->
        :root

      true ->
        :student
    end
  end

  defp shown?(html, selector), do: find_html_elements(html, selector) != []

  defp headings(html), do: html |> find_html_elements("h1") |> Enum.map(&normalized_text/1)

  defp paragraphs(html), do: html |> find_html_elements("p") |> Enum.map(&normalized_text/1)

  defp dd_value(html, title) do
    html
    |> find_html_elements("dl > div")
    |> Enum.find_value(fn row ->
      titles = row |> find_html_elements("dt") |> Enum.map(&normalized_text/1)

      if title in titles do
        row |> find_html_elements("dd") |> List.first() |> normalized_text()
      end
    end)
  end

  defp server_cards(html) do
    html
    |> find_html_elements(".card")
    |> Enum.filter(fn card -> find_html_elements(card, "a[href^='/servers/']") != [] end)
    |> Map.new(fn card ->
      [link | _rest] = find_html_elements(card, "a[href^='/servers/']")
      [name_element | _badge] = find_html_elements(card, ".card-title > div")
      [badge_element | _rest] = find_html_elements(card, ".card-title .badge")

      {html_element_attribute(link, "href"),
       %{name: normalized_text(name_element), badge: normalized_text(badge_element)}}
    end)
  end

  defp normalized_text(element),
    do: element |> html_element_text() |> String.split() |> Enum.join(" ")

  defp form_errors(html, form_id),
    do:
      html
      |> find_html_elements("##{form_id} p.text-error")
      |> Enum.map(&html_element_text/1)
end
