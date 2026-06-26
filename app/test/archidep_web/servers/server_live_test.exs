defmodule ArchiDepWeb.Servers.ServerLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClientMock
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  describe "the server detail page as an admin" do
    setup :register_and_log_in_root

    test "render the server detail page", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)

      {:ok, _view, html} = live(conn, "/admin/servers/#{server.id}")

      assert_html_title(html, "web-01 · ArchiDep")
      assert server_page(html, server) == expected_admin_page()
    end

    test "redirect to the dashboard when the server is not found", %{conn: conn, auth: auth} do
      server_id = UUID.generate()

      stub(Servers.ContextMock, :fetch_server, fn ^auth, _id -> {:error, :server_not_found} end)

      assert {:error, {:live_redirect, %{flash: flash, to: "/app"}}} =
               live(conn, "/admin/servers/#{server_id}")

      assert redirect_notifications(flash) == [{:error, gettext("Server not found")}]
    end
  end

  describe "the server detail page as the owner" do
    setup :register_and_log_in_student

    test "render only the owner-visible details", %{conn: conn, auth: auth, student: student} do
      server = build_server()
      stub_server_page(auth, server)
      stub(Course.ContextMock, :fetch_authenticated_student, fn ^auth -> {:ok, student} end)

      {:ok, _view, html} = live(conn, "/servers/#{server.id}")

      assert_html_title(html, "web-01 · ArchiDep")

      # The owner sees neither the group/owner rows nor the delete affordances
      # (both root-only); the edit dialog is available to every principal.
      assert server_page(html, server) == %{
               heading: "web-01",
               details: %{
                 "IP address" => "192.168.1.10",
                 "Username" => "deploy",
                 "Domain" => "alice.archidep.ch",
                 "SSH port" => "2222",
                 "Active" => :active
               },
               edit_button: :enabled,
               edit_dialog: true,
               delete_button: :absent,
               delete_dialog: false
             }
    end
  end

  describe "the edit server dialog" do
    setup :register_and_log_in_root

    test "validate the edited server against the context", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      invalid = Changeset.add_error(Changeset.change(%Server{}), :username, "is invalid")
      valid = Changeset.change(%Server{})

      expect(Servers.ContextMock, :validate_existing_server, fn ^auth,
                                                                ^server_id,
                                                                %{username: "bad user"} ->
        {:ok, invalid}
      end)

      expect(Servers.ContextMock, :validate_existing_server, fn ^auth,
                                                                ^server_id,
                                                                %{username: "gooduser"} ->
        {:ok, valid}
      end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      assert view
             |> form("#edit-server-form", server: %{username: "bad user"})
             |> render_change()
             |> form_errors("edit-server-form") == ["is invalid"]

      assert view
             |> form("#edit-server-form", server: %{username: "gooduser"})
             |> render_change()
             |> form_errors("edit-server-form") == []
    end

    test "update the server from a full submission", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      updated = build_server(name: "web-02")
      test_pid = self()

      expect(Servers.ContextMock, :update_server, fn ^auth, ^server_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated, EventsFactory.build(:event_reference)}
      end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      view
      |> form("#edit-server-form",
        server: %{
          name: "web-02",
          ip_address: "10.0.0.5",
          username: "deploy2",
          ssh_port: "2244",
          ssh_host_key_fingerprints: "SHA256:newfingerprint",
          active: "true",
          app_username: "appdeploy",
          expected_properties: %{
            cpus: "4",
            cores: "2",
            vcpus: "8",
            memory: "2048",
            swap: "1024",
            system: "Linux",
            architecture: "x86_64",
            os_family: "Debian",
            distribution: "Ubuntu",
            distribution_release: "noble",
            distribution_version: "24.04"
          }
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "web-02",
               ip_address: "10.0.0.5",
               username: "deploy2",
               ssh_port: 2244,
               ssh_host_key_fingerprints: "SHA256:newfingerprint",
               active: true,
               app_username: "appdeploy",
               expected_properties: %{
                 cpus: 4,
                 cores: 2,
                 vcpus: 8,
                 memory: 2048,
                 swap: 1024,
                 system: "Linux",
                 architecture: "x86_64",
                 os_family: "Debian",
                 distribution: "Ubuntu",
                 distribution_release: "noble",
                 distribution_version: "24.04"
               }
             }

      edit_dialog_id = "#edit-server-dialog-#{server.id}"
      assert_push_event(view, "execute-action", %{to: ^edit_dialog_id, action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Updated server {server}", server: "web-02")
      )
    end

    test "update the server clearing every optional field", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      updated = build_server(name: "web-02")
      test_pid = self()

      expect(Servers.ContextMock, :update_server, fn ^auth, ^server_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated, EventsFactory.build(:event_reference)}
      end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      view
      |> form("#edit-server-form",
        server: %{
          name: "",
          ip_address: "10.0.0.5",
          username: "deploy2",
          ssh_port: "",
          ssh_host_key_fingerprints: "SHA256:keep",
          active: "true",
          app_username: "archidep",
          expected_properties: %{
            cpus: "",
            cores: "",
            vcpus: "",
            memory: "",
            swap: "",
            system: "",
            architecture: "",
            os_family: "",
            distribution: "",
            distribution_release: "",
            distribution_version: ""
          }
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: nil,
               ip_address: "10.0.0.5",
               username: "deploy2",
               ssh_port: nil,
               ssh_host_key_fingerprints: "SHA256:keep",
               active: true,
               app_username: "archidep",
               expected_properties: %{
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

      assert_flash_notification(
        view,
        :success,
        gettext("Updated server {server}", server: "web-02")
      )
    end

    test "render errors when the server cannot be updated", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      {:error, errored} =
        %Server{}
        |> Changeset.cast(%{"name" => "web-x"}, [:name])
        |> Changeset.add_error(:name, "has already been taken")
        |> Changeset.apply_action(:update)

      expect(Servers.ContextMock, :update_server, fn ^auth, ^server_id, _data ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      assert view
             |> form("#edit-server-form", server: %{name: "web-x"})
             |> render_submit()
             |> form_errors("edit-server-form") == ["has already been taken"]

      assert_flash_notification(view, :error, gettext("The form is invalid."))

      refute_push_event(view, "execute-action", %{action: "close"})
    end
  end

  describe "the delete server dialog" do
    setup :register_and_log_in_root

    test "delete the server", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      expect(Servers.ContextMock, :delete_server, fn ^auth, ^server_id -> :ok end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      view
      |> element(~s(#delete-server-dialog-#{server.id} button[phx-click="delete"]))
      |> render_click()

      assert flash_notifications(view) == []
      refute_push_event(view, "execute-action", %{action: "close"})
    end
  end

  describe "live updates" do
    setup :register_and_log_in_root

    test "reflect a server name update broadcast over PubSub", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)

      {:ok, view, html} = live(conn, "/admin/servers/#{server.id}")

      assert server_page(html, server) == expected_admin_page()

      updated = %{server | name: "web-renamed", version: server.version + 1}
      :ok = PubSub.publish_server_updated(updated)

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.server.name == "web-renamed" end,
        "server renamed"
      )

      assert server_page(render(view), server) == expected_admin_page(%{heading: "web-renamed"})
    end

    test "disable the edit and delete actions when the tracker reports a busy server", %{
      conn: conn,
      auth: auth
    } do
      server = build_server()
      stub_server_page(auth, server)

      {:ok, view, html} = live(conn, "/admin/servers/#{server.id}")

      assert server_page(html, server) == expected_admin_page()

      busy_state =
        real_time_state(server,
          connection_state: ServersFactory.random_connecting_state(%{retrying: false})
        )

      send(view.pid, {:server_state, server.id, busy_state})

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.state == busy_state end,
        "server state updated"
      )

      assert server_page(render(view), server) ==
               expected_admin_page(%{edit_button: :disabled, delete_button: :disabled})
    end

    test "navigate to the admin dashboard when the server is deleted over PubSub", %{
      conn: conn,
      auth: auth
    } do
      server = build_server()
      stub_server_page(auth, server)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      :ok = PubSub.publish_server_deleted(server)

      flash = assert_redirect(view, "/admin")

      assert redirect_notifications(flash) == [
               {:success, gettext("Deleted server {server}", server: "web-01")}
             ]
    end
  end

  describe "retry handlers" do
    setup :register_and_log_in_root

    test "retry connecting delegates to the context", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      expect(Servers.ContextMock, :retry_connecting, fn ^auth, ^server_id -> :ok end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      render_hook(view, "retry_connecting", %{"server_id" => server.id})

      assert flash_notifications(view) == []
    end

    test "retry the Ansible playbook delegates to the context", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      expect(Servers.ContextMock, :retry_ansible_playbook, fn ^auth, ^server_id, "setup" ->
        :ok
      end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      render_hook(view, "retry_operation", %{
        "server_id" => server.id,
        "operation" => "ansible-playbook",
        "playbook" => "setup"
      })

      assert flash_notifications(view) == []
    end

    test "retry checking open ports delegates to the context", %{conn: conn, auth: auth} do
      server = build_server()
      stub_server_page(auth, server)
      server_id = server.id

      expect(Servers.ContextMock, :retry_checking_open_ports, fn ^auth, ^server_id -> :ok end)

      {:ok, view, _html} = live(conn, "/admin/servers/#{server.id}")

      render_hook(view, "retry_operation", %{
        "server_id" => server.id,
        "operation" => "check-open-ports"
      })

      assert flash_notifications(view) == []
    end
  end

  test "accessing the server page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, "/servers/#{UUID.generate()}")
  end

  defp build_server(overrides \\ []) do
    group = ServersFactory.build(:server_group, name: "Crypto 101")

    owner =
      ServersFactory.build(:server_owner,
        root: false,
        group_member:
          ServersFactory.build(:server_group_member,
            name: "Alice Owner",
            domain: "alice.archidep.ch"
          )
      )

    ServersFactory.build(
      :server,
      Keyword.merge(
        [
          name: "web-01",
          ip_address: %Postgrex.INET{address: {192, 168, 1, 10}, netmask: nil},
          username: "deploy",
          ssh_port: 2222,
          active: true,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id
        ],
        overrides
      )
    )
  end

  # The detail page reads the server on both the disconnected and connected
  # mounts, and the tracker client is reached once per mount (its `start_link`
  # only on the connected one), so these ambient reads fire a variable number of
  # times. They are stubbed so each test can `expect` only the mutation it
  # asserts. The tracker returns no real-time state, which renders the page in
  # its initial (no-connection) shape.
  defp stub_server_page(auth, server) do
    stub(Servers.ContextMock, :fetch_server, fn ^auth, _id -> {:ok, server} end)
    stub(ServerTrackerClientMock, :start_link, fn ^server -> {:ok, self()} end)
    stub(ServerTrackerClientMock, :get_current_server_state, fn ^server -> nil end)
    :ok
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

  # The well-known shape of the admin-rendered page, with overrides for the facet
  # a test exercises (e.g. the action buttons becoming `:disabled` for a busy
  # server). Mirrors `build_server/1`'s default fixture.
  defp expected_admin_page(overrides \\ %{}),
    do:
      Map.merge(
        %{
          heading: "web-01",
          details: %{
            "IP address" => "192.168.1.10",
            "Username" => "deploy",
            "Domain" => "alice.archidep.ch",
            "SSH port" => "2222",
            "Active" => :active,
            "Group" => "Crypto 101",
            "Owner" => "Alice Owner"
          },
          edit_button: :enabled,
          edit_dialog: true,
          delete_button: :enabled,
          delete_dialog: true
        },
        overrides
      )

  # Projects the whole observable server page: the heading, the data-display
  # rows, and the edit/delete affordances. Each action button projects to
  # `:enabled` / `:disabled` (its `disabled` attribute tracks the real-time
  # server state) or `:absent` when the principal cannot see it; each dialog
  # projects to its presence.
  defp server_page(html, server),
    do: %{
      heading: server_heading(html),
      details: server_detail(html),
      edit_button: button_state(html, "#edit-server-button"),
      edit_dialog: present?(html, "#edit-server-dialog-#{server.id}"),
      delete_button: button_state(html, "#delete-server-button"),
      delete_dialog: present?(html, "#delete-server-dialog-#{server.id}")
    }

  defp button_state(html, selector) do
    case find_html_elements(html, selector) do
      [button] ->
        if html_element_attribute(button, "disabled") != nil, do: :disabled, else: :enabled

      [] ->
        :absent
    end
  end

  defp present?(html, selector), do: find_html_elements(html, selector) != []

  defp server_heading(html) do
    [heading | _rest] = find_html_elements(html, "h2")
    html_element_text(heading)
  end

  # Projects the server data display (the page's only `<dl>`) to a title-keyed
  # map of meaningful values; the active row projects to `:active`/`:inactive`
  # via its icon since the cell holds no text.
  defp server_detail(html) do
    titles = html |> find_html_elements("dl dt") |> Enum.map(&html_element_text/1)
    values = find_html_elements(html, "dl dd")

    titles
    |> Enum.zip(values)
    |> Map.new(fn {title, value} -> {title, detail_value(title, value)} end)
  end

  defp detail_value("Active", value),
    do: if(find_html_elements(value, ".text-success") != [], do: :active, else: :inactive)

  defp detail_value(_title, value), do: html_element_text(value)

  defp form_errors(html, form_id),
    do:
      html
      |> find_html_elements("##{form_id} p.text-error")
      |> Enum.map(&html_element_text/1)

  defp redirect_notifications(flash),
    do:
      flash
      |> Map.values()
      |> Enum.map(fn notification -> {notification.type, notification.message} end)
end
