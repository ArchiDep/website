defmodule ArchiDepWeb.Admin.Classes.StudentLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true
  use ArchiDepWeb, :verified_routes

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Events.StudentDeleted
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Course.UseCases.ReadStudents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.UseCases.ReadServers
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  @now ~U[2026-06-27 12:00:00Z]

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "the student detail page" do
    setup :register_and_log_in_root

    test "render a fully-registered student with an active server", %{conn: conn, auth: auth} do
      student_id = UUID.generate()

      class =
        CourseFactory.build(:class,
          name: "Crypto 101",
          now: @now,
          active: true,
          start_date: nil,
          end_date: nil,
          servers_enabled: false
        )

      student =
        build_student(
          id: student_id,
          class: class,
          name: "Alice Cooper",
          email: "alice@example.org",
          academic_class: "INF-1",
          username: "alice",
          username_confirmed: true,
          domain: "alice.archidep.ch",
          active: true,
          servers_enabled: true,
          user: CourseFactory.build(:user, student: nil, student_id: student_id)
        )

      active_server = build_active_server(student, name: "web-01")
      stub_student_page(auth, student: student, active_server_result: {:ok, active_server})

      {:ok, _view, html} = live(conn, path(student))

      assert_html_title(html, "Alice Cooper · Crypto 101 · Admin · ArchiDep")

      assert student_page(html) == %{
               heading: "Alice Cooper",
               data_display: %{
                 name: "Alice Cooper",
                 email: "alice@example.org",
                 class: "Crypto 101",
                 academic_class: "INF-1",
                 server_username: "alice",
                 active: :active,
                 servers_enabled: :active,
                 servers_enabled_note: gettext("disabled for class"),
                 domain: "alice.archidep.ch",
                 user_account: "alice",
                 active_server: "web-01"
               },
               edit_dialog?: true,
               delete_dialog?: true,
               impersonate?: true,
               login_link?: false
             }
    end

    test "render an unregistered student with no academic class and no server", %{
      conn: conn,
      auth: auth
    } do
      class =
        CourseFactory.build(:class,
          name: "Crypto 101",
          now: @now,
          active: true,
          start_date: nil,
          end_date: nil,
          servers_enabled: false
        )

      student =
        build_student(
          class: class,
          name: "Bob Marley",
          email: "bob@example.org",
          academic_class: nil,
          username: "bob",
          username_confirmed: false,
          domain: "bob.archidep.ch",
          active: false,
          servers_enabled: false,
          user: nil
        )

      stub_student_page(auth, student: student)

      {:ok, _view, html} = live(conn, path(student))

      assert student_page(html) == %{
               heading: "Bob Marley",
               data_display: %{
                 name: "Bob Marley",
                 email: "bob@example.org",
                 class: "Crypto 101",
                 academic_class: "-",
                 server_username: "bob (#{gettext("suggested")})",
                 active: :inactive,
                 servers_enabled: :inactive,
                 servers_enabled_note: "",
                 domain: "bob.archidep.ch",
                 user_account: gettext("Not registered yet"),
                 active_server: gettext("None registered")
               },
               edit_dialog?: true,
               delete_dialog?: true,
               impersonate?: false,
               login_link?: false
             }
    end

    test "redirect to the class when the student is not found", %{conn: conn, auth: auth} do
      class_id = UUID.generate()
      student_id = UUID.generate()

      stub(Course.ContextMock, :fetch_student_in_class, fn ^auth, ^class_id, ^student_id ->
        {:error, :student_not_found}
      end)

      assert {:error, {:live_redirect, %{flash: flash, to: to}}} =
               live(conn, "/admin/classes/#{class_id}/students/#{student_id}")

      assert to == "/admin/classes/#{class_id}"
      assert redirect_notifications(flash) == [{:error, gettext("Student not found")}]
    end
  end

  describe "generating a login link" do
    setup :register_and_log_in_root

    test "generate a login link for the student", %{conn: conn, auth: auth} do
      student = build_student(name: "Alice")
      stub_student_page(auth, student: student)
      student_id = student.id

      login_link = AccountsFactory.build(:login_link, token: <<1, 2, 3, 4>>)

      expect(Accounts.ContextMock, :create_login_link_for_preregistered_user, fn ^auth,
                                                                                 ^student_id ->
        {:ok, login_link}
      end)

      {:ok, view, _html} = live(conn, path(student))

      html = view |> element("button", gettext("Generate login link")) |> render_click()

      assert_flash_notification(view, :success, gettext("Login link generated"))

      assert login_link_url(html) ==
               url(~p"/auth/link?#{%{token: Base.encode64(<<1, 2, 3, 4>>)}}")
    end

    test "redirect to the class when the student no longer exists", %{conn: conn, auth: auth} do
      student = build_student(name: "Alice")
      stub_student_page(auth, student: student)
      student_id = student.id

      expect(Accounts.ContextMock, :create_login_link_for_preregistered_user, fn ^auth,
                                                                                 ^student_id ->
        {:error, :preregistered_user_not_found}
      end)

      {:ok, view, _html} = live(conn, path(student))

      view |> element("button", gettext("Generate login link")) |> render_click()

      flash = assert_redirect(view, "/admin/classes/#{student.class_id}")
      assert redirect_notifications(flash) == [{:error, gettext("Student not found")}]
    end
  end

  describe "the edit student dialog" do
    setup :register_and_log_in_root

    test "validate the edited student against the context", %{conn: conn, auth: auth} do
      student = build_student(name: "Original")
      stub_student_page(auth, student: student)
      student_id = student.id

      invalid =
        student
        |> Changeset.cast(%{"name" => "Bad"}, [:name])
        |> Changeset.add_error(:name, "is invalid")

      valid = Changeset.cast(student, %{"name" => "Good"}, [:name])

      expect(Course.ContextMock, :validate_existing_student, fn ^auth,
                                                                ^student_id,
                                                                %{name: "Bad"} ->
        {:ok, invalid}
      end)

      expect(Course.ContextMock, :validate_existing_student, fn ^auth,
                                                                ^student_id,
                                                                %{name: "Good"} ->
        {:ok, valid}
      end)

      {:ok, view, _html} = live(conn, path(student))

      assert view
             |> form("#edit-student-form", student: %{name: "Bad"})
             |> render_change()
             |> form_errors("edit-student-form") == ["is invalid"]

      assert view
             |> form("#edit-student-form", student: %{name: "Good"})
             |> render_change()
             |> form_errors("edit-student-form") == []
    end

    test "update the student from a full submission", %{conn: conn, auth: auth} do
      student = build_student(name: "Original", academic_class: nil)
      stub_student_page(auth, student: student)
      student_id = student.id

      updated = %{student | name: "Alice Updated"}
      test_pid = self()

      expect(Course.ContextMock, :update_student, fn ^auth, ^student_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated}
      end)

      {:ok, view, _html} = live(conn, path(student))

      view
      |> form("#edit-student-form",
        student: %{
          name: "Alice Updated",
          email: "alice.updated@example.org",
          academic_class: "INF-2",
          username: "aliceu",
          domain: "aliceu.archidep.ch",
          active: "true",
          servers_enabled: "true"
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "Alice Updated",
               email: "alice.updated@example.org",
               academic_class: "INF-2",
               username: "aliceu",
               domain: "aliceu.archidep.ch",
               active: true,
               servers_enabled: true
             }

      dialog_id = "#edit-student-dialog-#{student.id}"
      assert_push_event(view, "execute-action", %{to: ^dialog_id, action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Updated student {student}", student: "Alice Updated")
      )
    end

    test "update the student clearing the academic class", %{conn: conn, auth: auth} do
      student = build_student(name: "Alice", academic_class: "INF-1")
      stub_student_page(auth, student: student)
      student_id = student.id

      updated = %{student | name: "Alice"}
      test_pid = self()

      expect(Course.ContextMock, :update_student, fn ^auth, ^student_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated}
      end)

      {:ok, view, _html} = live(conn, path(student))

      view
      |> form("#edit-student-form",
        student: %{
          name: "Alice",
          email: "alice@example.org",
          academic_class: "",
          username: "alice",
          domain: "alice.archidep.ch",
          active: "false",
          servers_enabled: "false"
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "Alice",
               email: "alice@example.org",
               academic_class: nil,
               username: "alice",
               domain: "alice.archidep.ch",
               active: false,
               servers_enabled: false
             }

      assert_flash_notification(
        view,
        :success,
        gettext("Updated student {student}", student: "Alice")
      )
    end

    test "render errors when the student cannot be updated", %{conn: conn, auth: auth} do
      student = build_student(name: "Original")
      stub_student_page(auth, student: student)
      student_id = student.id

      {:error, errored} =
        student
        |> Changeset.cast(%{"username" => "taken"}, [:username])
        |> Changeset.add_error(:username, "has already been taken")
        |> Changeset.apply_action(:update)

      expect(Course.ContextMock, :update_student, fn ^auth, ^student_id, _data ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, path(student))

      assert view
             |> form("#edit-student-form", student: %{username: "taken"})
             |> render_submit()
             |> form_errors("edit-student-form") == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end
  end

  describe "the delete student dialog" do
    setup :register_and_log_in_root

    test "delete the student", %{conn: conn, auth: auth} do
      student = build_student(name: "Doomed")
      stub_student_page(auth, student: student)
      student_id = student.id

      expect(Course.ContextMock, :delete_student, fn ^auth, ^student_id -> :ok end)

      {:ok, view, _html} = live(conn, path(student))

      view
      |> element(~s(#delete-student-dialog-#{student.id} button[phx-click="delete"]))
      |> render_click()

      assert flash_notifications(view) == []
      refute_push_event(view, "execute-action", %{action: "close"})
    end
  end

  describe "live updates" do
    setup :register_and_log_in_root

    test "reflect a student update broadcast over PubSub", %{conn: conn, auth: auth} do
      student = build_alice([])
      stub_student_page(auth, student: student)

      {:ok, view, html} = live(conn, path(student))

      assert student_page(html) == alice_page()

      updated = %{student | name: "Renamed", version: student.version + 1}

      :ok =
        Course.PubSub.publish_student_updated(
          updated,
          StudentUpdated.new(updated),
          EventsFactory.build(:event_reference, version: updated.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.student.name == "Renamed" end,
        "student renamed"
      )

      assert student_page(render(view)) ==
               alice_page(%{name: "Renamed"}, %{heading: "Renamed"})
    end

    test "navigate away when the student is deleted over PubSub", %{conn: conn, auth: auth} do
      student = build_student(name: "Gone")
      stub_student_page(auth, student: student)

      {:ok, view, _html} = live(conn, path(student))

      :ok =
        Course.PubSub.publish_student_deleted(
          StudentDeleted.new(student),
          EventsFactory.build(:event_reference)
        )

      flash = assert_redirect(view, "/admin/classes/#{student.class_id}")

      assert redirect_notifications(flash) == [
               {:success, gettext("Deleted student {student}", student: "Gone")}
             ]
    end

    test "reflect a class update broadcast over PubSub", %{conn: conn, auth: auth} do
      student = build_alice([])
      stub_student_page(auth, student: student)

      {:ok, view, html} = live(conn, path(student))

      assert student_page(html) == alice_page()

      updated_class = %{student.class | name: "Renamed Class", version: student.class.version + 1}

      :ok =
        Course.PubSub.publish_class_updated(
          updated_class,
          ClassUpdated.new(updated_class),
          EventsFactory.build(:event_reference, version: updated_class.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.student.class.name == "Renamed Class" end,
        "class renamed"
      )

      assert student_page(render(view)) == alice_page(%{class: "Renamed Class"})
    end

    test "one class update refreshes both the student and its active server", %{
      conn: conn,
      auth: auth
    } do
      # A single `:class_updated` event must reach both refreshers on the page's
      # `attach_all` hook: the student's nested class is renamed, and the active
      # server (absent at mount, available by the time the update arrives) is
      # looked up — proving neither read-model starves the other.
      student = build_alice([])

      {:ok, active_server_lookup} = Agent.start_link(fn -> {:error, :server_not_found} end)

      stub(Course.ContextMock, :fetch_student_in_class, fn ^auth, _class_id, _id ->
        {:ok, StudentView.from(student)}
      end)

      stub(Servers.ContextMock, :fetch_active_server_for_group_member, fn ^auth, _id ->
        case Agent.get(active_server_lookup, & &1) do
          {:ok, server} -> {:ok, ServerView.from(server)}
          other -> other
        end
      end)

      stub_student_read_models()

      {:ok, view, html} = live(conn, path(student))
      assert student_page(html) == alice_page()

      server = build_active_server(student, name: "web-01")
      :ok = Agent.update(active_server_lookup, fn _previous -> {:ok, server} end)

      updated_class = %{student.class | name: "Renamed Class", version: student.class.version + 1}

      :ok =
        Course.PubSub.publish_class_updated(
          updated_class,
          ClassUpdated.new(updated_class),
          EventsFactory.build(:event_reference, version: updated_class.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          assigns.student.class.name == "Renamed Class" and assigns.active_server != nil
        end,
        "class renamed and active server found"
      )

      assert student_page(render(view)) ==
               alice_page(%{class: "Renamed Class", active_server: "web-01"})
    end

    test "navigate away when the class is deleted over PubSub", %{conn: conn, auth: auth} do
      student = build_student(name: "Alice")
      stub_student_page(auth, student: student)

      {:ok, view, _html} = live(conn, path(student))

      :ok =
        Course.PubSub.publish_class_deleted(
          ClassDeleted.new(student.class),
          EventsFactory.build(:event_reference)
        )

      flash = assert_redirect(view, "/admin/classes")

      assert redirect_notifications(flash) == [
               {:warning, gettext("Class {class} has been deleted", class: student.class.name)}
             ]
    end

    test "show the active server when one is created over PubSub", %{conn: conn, auth: auth} do
      student = build_alice([])
      created = build_active_server(student, name: "web-01")

      # No active server at mount; the created server becomes the member's
      # active one, so the refresher's authoritative re-fetch returns it.
      {:ok, active_lookup} = Agent.start_link(fn -> {:error, :server_not_found} end)
      stub_student_page(auth, student: student)

      stub(Servers.ContextMock, :fetch_active_server_for_group_member, fn ^auth, _id ->
        case Agent.get(active_lookup, & &1) do
          {:ok, server} -> {:ok, ServerView.from(server)}
          other -> other
        end
      end)

      {:ok, view, html} = live(conn, path(student))

      assert student_page(html) == alice_page()

      :ok = Agent.update(active_lookup, fn _previous -> {:ok, created} end)

      :ok =
        Servers.PubSub.publish_server_created(
          ServerCreated.new(created),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.active_server != nil end,
        "active server created"
      )

      assert student_page(render(view)) == alice_page(%{active_server: "web-01"})
    end

    test "show the active server when an inactive one becomes active over PubSub", %{
      conn: conn,
      auth: auth
    } do
      student = build_alice([])
      updated = build_active_server(student, name: "web-01")

      # No active server at mount; the server becomes active by the time its
      # update arrives, so the refresher's re-fetch surfaces it.
      {:ok, active_lookup} = Agent.start_link(fn -> {:error, :server_not_found} end)
      stub_student_page(auth, student: student)

      stub(Servers.ContextMock, :fetch_active_server_for_group_member, fn ^auth, _id ->
        case Agent.get(active_lookup, & &1) do
          {:ok, server} -> {:ok, ServerView.from(server)}
          other -> other
        end
      end)

      {:ok, view, html} = live(conn, path(student))

      assert student_page(html) == alice_page()

      :ok = Agent.update(active_lookup, fn _previous -> {:ok, updated} end)

      :ok =
        Servers.PubSub.publish_server_updated(
          ServerUpdated.new(updated),
          EventsFactory.build(:event_reference, version: updated.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.active_server != nil end,
        "active server updated"
      )

      assert student_page(render(view)) == alice_page(%{active_server: "web-01"})
    end

    test "drop the active server when it is deleted over PubSub", %{conn: conn, auth: auth} do
      student = build_alice([])
      active_server = build_active_server(student, name: "web-01")
      stub_student_page(auth, student: student, active_server_result: {:ok, active_server})

      {:ok, view, html} = live(conn, path(student))

      assert student_page(html) == alice_page(%{active_server: "web-01"})

      :ok =
        Servers.PubSub.publish_server_deleted(
          ServerDeleted.new(active_server),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.active_server == nil end,
        "active server deleted"
      )

      assert student_page(render(view)) == alice_page()
    end
  end

  test "accessing the student page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(
      conn,
      "/admin/classes/#{UUID.generate()}/students/#{UUID.generate()}"
    )
  end

  # A fully-pinned registered student paired with `alice_page/2` so the live
  # update tests can assert the whole page projection before and after each
  # broadcast. Every value the projection reads is fixed here.
  defp build_alice(opts) do
    student_id = Keyword.get(opts, :id, UUID.generate())

    class =
      CourseFactory.build(:class,
        name: "Crypto 101",
        now: @now,
        active: true,
        servers_enabled: false
      )

    build_student(
      Keyword.merge(
        [
          id: student_id,
          class: class,
          name: "Alice",
          email: "alice@example.org",
          academic_class: "INF-1",
          username: "alice",
          username_confirmed: true,
          domain: "alice.archidep.ch",
          active: true,
          servers_enabled: false,
          user: CourseFactory.build(:user, student: nil, student_id: student_id)
        ],
        opts
      )
    )
  end

  defp alice_page(data_display_overrides \\ %{}, page_overrides \\ %{}) do
    Map.merge(
      %{
        heading: "Alice",
        data_display:
          Map.merge(
            %{
              name: "Alice",
              email: "alice@example.org",
              class: "Crypto 101",
              academic_class: "INF-1",
              server_username: "alice",
              active: :active,
              servers_enabled: :inactive,
              servers_enabled_note: "",
              domain: "alice.archidep.ch",
              user_account: "alice",
              active_server: gettext("None registered")
            },
            data_display_overrides
          ),
        edit_dialog?: true,
        delete_dialog?: true,
        impersonate?: true,
        login_link?: false
      },
      page_overrides
    )
  end

  defp build_student(opts) do
    {class, opts} =
      Keyword.pop_lazy(opts, :class, fn ->
        CourseFactory.build(:class, now: @now, active: true, start_date: nil, end_date: nil)
      end)

    CourseFactory.build(
      :student,
      Keyword.merge([class: class, class_id: class.id, now: @now], opts)
    )
  end

  # Builds a server that is unconditionally active at any instant (a root,
  # active, group-member-less owner and a date-window-less active group), so the
  # `ServerView.active?` checks in the active-server refresher are
  # deterministic. The owner is the student's linked user account so the
  # broadcast reaches the page.
  defp build_active_server(student, opts) do
    ServersFactory.build(
      :server,
      Keyword.merge(
        [
          active: true,
          owner_id: student.user_id,
          group:
            ServersFactory.build(:server_group, active: true, start_date: nil, end_date: nil),
          owner:
            ServersFactory.build(:server_owner,
              id: student.user_id,
              root: true,
              active: true,
              group_member: nil
            )
        ],
        opts
      )
    )
  end

  # The page fetches the student and its active server on every mount
  # (disconnected and connected), so these ambient reads are stubbed and each
  # test `expect`s only the mutation it asserts.
  defp stub_student_page(auth, opts) do
    student = Keyword.fetch!(opts, :student)

    active_server_result =
      case Keyword.get(opts, :active_server_result, {:error, :server_not_found}) do
        {:ok, server} -> {:ok, ServerView.from(server)}
        other -> other
      end

    stub(Course.ContextMock, :fetch_student_in_class, fn ^auth, _class_id, _id ->
      {:ok, StudentView.from(student)}
    end)

    stub(Servers.ContextMock, :fetch_active_server_for_group_member, fn ^auth, _id ->
      active_server_result
    end)

    stub_student_read_models()

    :ok
  end

  # The read-model subscriptions and reconcilers delegate to the real use cases,
  # so a real broadcast drives the view and the reconcilers exercise the real
  # merge logic (their fetches go through the mocked context boundary).
  defp stub_student_read_models do
    stub(Course.ContextMock, :subscribe_student_detail, &ReadStudents.subscribe_student_detail/1)
    stub(Course.ContextMock, :refresh_student_detail, &ReadStudents.refresh_student_detail/2)

    stub(
      Servers.ContextMock,
      :subscribe_active_server_for_member,
      &ReadServers.subscribe_active_server_for_member/1
    )

    stub(
      Servers.ContextMock,
      :refresh_active_server_for_member,
      &ReadServers.refresh_active_server_for_member/4
    )

    :ok
  end

  defp path(student), do: "/admin/classes/#{student.class_id}/students/#{student.id}"

  # Projects the page to its meaningful regions: the heading, the whole data
  # display (each row by its title), and the affordances (the always-rendered
  # edit/delete dialogs and the conditional impersonate button / login link).
  defp student_page(html) do
    %{
      heading: html |> find_html_elements("h2") |> List.first() |> html_element_text(),
      data_display: data_display(html),
      edit_dialog?: find_html_elements(html, "#edit-student-form") != [],
      delete_dialog?: find_html_elements(html, ~s(button[phx-click="delete"])) != [],
      impersonate?: find_html_elements(html, "button[name='user_account_id']") != [],
      login_link?: find_html_elements(html, "input[readonly]") != []
    }
  end

  defp data_display(html) do
    rows =
      html
      |> find_html_elements("dl > div")
      |> Map.new(fn row ->
        [dt] = find_html_elements(row, "dt")
        [dd] = find_html_elements(row, "dd")
        {html_element_text(dt), dd}
      end)

    %{
      name: html_element_text(rows[gettext("Name")]),
      email: html_element_text(rows[gettext("Email")]),
      class: html_element_text(rows[gettext("Class")]),
      academic_class: html_element_text(rows[gettext("Academic class")]),
      server_username: html_element_text(rows[gettext("Server username")]),
      active: icon_state(rows[gettext("Active")]),
      servers_enabled: icon_state(rows[gettext("Servers enabled")]),
      servers_enabled_note: html_element_text(rows[gettext("Servers enabled")]),
      domain: html_element_text(rows[gettext("Domain")]),
      user_account: html_element_text(rows[gettext("User account")]),
      active_server: html_element_text(rows[gettext("Active server")])
    }
  end

  defp icon_state(element),
    do: if(find_html_elements(element, ".text-success") != [], do: :active, else: :inactive)

  defp login_link_url(html) do
    [input] = find_html_elements(html, "input[readonly]")
    html_element_attribute(input, "value")
  end

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
