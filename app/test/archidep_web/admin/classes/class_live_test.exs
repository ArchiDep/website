defmodule ArchiDepWeb.Admin.Classes.ClassLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Servers
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.Changeset

  setup :verify_on_exit!

  describe "the class detail page" do
    setup :register_and_log_in_root

    test "render the class detail page", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          name: "Crypto 101",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31],
          active: true,
          servers_enabled: false,
          teacher_ssh_public_keys: []
        )

      stub_class_page(auth, class: class, server_group: server_group)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert_html_title(html, "Crypto 101 · Admin · ArchiDep")

      assert class_detail(html) == %{
               start_date: "Tue, September 01, 2026",
               end_date: "Thu, December 31, 2026",
               active: :active,
               servers_enabled: :inactive,
               teacher_ssh_public_keys_count: "0"
             }

      assert has_element?(view, "#edit-class-dialog-#{class.id}")
      assert has_element?(view, "#edit-class-form")
      assert has_element?(view, "#delete-class-dialog-#{class.id}")
    end

    test "redirect to the classes list when the class is not found", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      stub(Servers.ContextMock, :fetch_server_group, fn ^auth, _id -> {:ok, server_group} end)
      stub(Course.ContextMock, :fetch_class, fn ^auth, _id -> {:error, :class_not_found} end)

      assert {:error, {:live_redirect, %{flash: flash, to: "/admin/classes"}}} =
               live(conn, "/admin/classes/#{class.id}")

      assert redirect_notifications(flash) == [{:error, gettext("Class not found")}]
    end

    test "redirect to the classes list when the server group is not found", %{
      conn: conn,
      auth: auth
    } do
      {class, _server_group} = build_class_and_group()

      stub(Course.ContextMock, :fetch_class, fn ^auth, _id -> {:ok, class} end)

      stub(Servers.ContextMock, :fetch_server_group, fn ^auth, _id ->
        {:error, :server_group_not_found}
      end)

      assert {:error, {:live_redirect, %{flash: flash, to: "/admin/classes"}}} =
               live(conn, "/admin/classes/#{class.id}")

      assert redirect_notifications(flash) == [{:error, gettext("Class not found")}]
    end
  end

  describe "the edit class dialog" do
    setup :register_and_log_in_root

    test "validate the edited class against the context", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original")
      stub_class_page(auth, class: class, server_group: server_group)
      class_id = class.id

      invalid = Changeset.add_error(Changeset.change(%Class{}), :name, "is invalid")
      valid = Changeset.change(%Class{})

      expect(Course.ContextMock, :validate_existing_class, fn ^auth, ^class_id, %{name: "Bad"} ->
        {:ok, invalid}
      end)

      expect(Course.ContextMock, :validate_existing_class, fn ^auth, ^class_id, %{name: "Good"} ->
        {:ok, valid}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("#edit-class-form", class: %{name: "Bad"})
             |> render_change()
             |> class_form_errors("edit-class-form") == ["is invalid"]

      assert view
             |> form("#edit-class-form", class: %{name: "Good"})
             |> render_change()
             |> class_form_errors("edit-class-form") == []
    end

    test "update the class from a full submission", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          name: "Original",
          start_date: nil,
          end_date: nil,
          active: false,
          servers_enabled: false,
          teacher_ssh_public_keys: [],
          ssh_exercise_vm_md5_host_key_fingerprints: nil,
          ssh_exercise_vm_sha256_host_key_fingerprints: nil
        )

      stub_class_page(auth, class: class, server_group: server_group)
      class_id = class.id

      updated = CourseFactory.build(:class, name: "Updated Class")
      test_pid = self()

      expect(Course.ContextMock, :update_class, fn ^auth, ^class_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> element(~s(#edit-class-form button[phx-click="add_teacher_ssh_public_key"]))
      |> render_click()

      view
      |> form("#edit-class-form",
        class: %{
          name: "Updated Class",
          start_date: "2026-09-01",
          end_date: "2026-12-31",
          active: "true",
          servers_enabled: "true",
          teacher_ssh_public_keys: %{"0" => %{value: "ssh-ed25519 AAAAKEY"}},
          ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
          ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "Updated Class",
               start_date: ~D[2026-09-01],
               end_date: ~D[2026-12-31],
               active: true,
               servers_enabled: true,
               teacher_ssh_public_keys: ["ssh-ed25519 AAAAKEY"],
               ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
               ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
             }

      edit_dialog_id = "#edit-class-dialog-#{class.id}"
      assert_push_event(view, "execute-action", %{to: ^edit_dialog_id, action: "close"})

      wait_for_socket_assigns!(
        view,
        &has_flash_notification?(&1, :success),
        "updated class notification"
      )

      assert flash_notifications(view) ==
               [{:success, gettext("Updated class {class}", class: "Updated Class")}]
    end

    test "update the class clearing every optional field", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          name: "Original",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31],
          active: true,
          servers_enabled: true,
          teacher_ssh_public_keys: [],
          ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
          ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
        )

      stub_class_page(auth, class: class, server_group: server_group)
      class_id = class.id

      updated = CourseFactory.build(:class, name: "Cleared")
      test_pid = self()

      expect(Course.ContextMock, :update_class, fn ^auth, ^class_id, data ->
        send(test_pid, {:updated_with, data})
        {:ok, updated}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("#edit-class-form",
        class: %{
          name: "Cleared",
          start_date: "",
          end_date: "",
          active: "false",
          servers_enabled: "false",
          ssh_exercise_vm_md5_host_key_fingerprints: "",
          ssh_exercise_vm_sha256_host_key_fingerprints: ""
        }
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
               name: "Cleared",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }
    end

    test "render errors when the class cannot be updated", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original")
      stub_class_page(auth, class: class, server_group: server_group)
      class_id = class.id

      {:error, errored} =
        %Class{}
        |> Changeset.change()
        |> Changeset.add_error(:name, "has already been taken")
        |> Changeset.apply_action(:update)

      expect(Course.ContextMock, :update_class, fn ^auth, ^class_id, %{name: "Taken"} ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("#edit-class-form", class: %{name: "Taken"})
             |> render_submit()
             |> class_form_errors("edit-class-form") == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "add a teacher SSH public key field", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original", teacher_ssh_public_keys: [])
      stub_class_page(auth, class: class, server_group: server_group)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      refute has_element?(
               view,
               ~s(#edit-class-form input[name^="class[teacher_ssh_public_keys]"])
             )

      assert view
             |> element(~s(#edit-class-form button[phx-click="add_teacher_ssh_public_key"]))
             |> render_click()
             |> find_html_elements(
               ~s(#edit-class-form input[type="text"][name^="class[teacher_ssh_public_keys]"])
             )
             |> length() == 1
    end
  end

  describe "the delete class dialog" do
    setup :register_and_log_in_root

    test "render a confirmation prompt when the class has no servers", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      stub_class_page(auth,
        class: class,
        server_group: server_group,
        server_ids: [],
        students: []
      )

      {:ok, _view, html} = live(conn, "/admin/classes/#{class.id}")

      assert delete_button_disabled?(html, class) == false

      assert delete_class_dialog_text(html, class, "p.mt-4") ==
               gettext("Are you sure you want to permanently delete this class?")

      assert delete_class_dialog_text(html, class, "p.text-warning") == nil
      assert delete_class_dialog_text(html, class, "p.text-error") == nil
    end

    test "warn about enrolled students", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      students = [CourseFactory.build(:student), CourseFactory.build(:student)]

      stub_class_page(auth,
        class: class,
        server_group: server_group,
        server_ids: [],
        students: students
      )

      {:ok, _view, html} = live(conn, "/admin/classes/#{class.id}")

      assert delete_button_disabled?(html, class) == false

      assert delete_class_dialog_text(html, class, "p.text-warning") ==
               "This class has 2 students enrolled, who will also be deleted. " <>
                 "Any user account linked to these students will lose access."
    end

    test "block deletion when the class has linked servers", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      stub_class_page(auth,
        class: class,
        server_group: server_group,
        server_ids: [UUID.generate()],
        students: []
      )

      {:ok, _view, html} = live(conn, "/admin/classes/#{class.id}")

      assert delete_button_disabled?(html, class) == true
      assert delete_class_dialog_text(html, class, "p.mt-4") == nil

      assert delete_class_dialog_text(html, class, "p.text-error") ==
               "This class cannot be deleted because 1 server is linked to it. " <>
                 "Delete that server before deleting the class."
    end

    test "delete the class", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      stub_class_page(auth,
        class: class,
        server_group: server_group,
        server_ids: [],
        students: []
      )

      class_id = class.id

      expect(Course.ContextMock, :delete_class, fn ^auth, ^class_id -> :ok end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> element(~s(#delete-class-dialog-#{class.id} button[phx-click="delete"]))
      |> render_click()

      assert flash_notifications(view) == []
      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "show an error when the class cannot be deleted", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Doomed")

      stub_class_page(auth,
        class: class,
        server_group: server_group,
        server_ids: [],
        students: []
      )

      class_id = class.id

      expect(Course.ContextMock, :delete_class, fn ^auth, ^class_id ->
        {:error, :class_has_servers}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> element(~s(#delete-class-dialog-#{class.id} button[phx-click="delete"]))
      |> render_click()

      wait_for_socket_assigns!(
        view,
        &has_flash_notification?(&1, :error),
        "delete error notification"
      )

      assert flash_notifications(view) ==
               [
                 {:error,
                  gettext(
                    "Class {class} cannot be deleted because at least one server is linked to it.",
                    class: "Doomed"
                  )}
               ]

      delete_dialog_id = "#delete-class-dialog-#{class.id}"
      assert_push_event(view, "execute-action", %{to: ^delete_dialog_id, action: "close"})
    end
  end

  describe "live updates" do
    setup :register_and_log_in_root

    test "reflect a class update broadcast over PubSub", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          name: "Original",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31],
          active: true,
          servers_enabled: false,
          teacher_ssh_public_keys: []
        )

      stub_class_page(auth, class: class, server_group: server_group)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_detail(html) == %{
               start_date: "Tue, September 01, 2026",
               end_date: "Thu, December 31, 2026",
               active: :active,
               servers_enabled: :inactive,
               teacher_ssh_public_keys_count: "0"
             }

      updated = %{class | name: "Renamed", active: false, version: class.version + 1}
      :ok = Course.PubSub.publish_class_updated(updated, EventsFactory.build(:event_reference))

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.class.name == "Renamed" end,
        "class updated"
      )

      assert class_detail(render(view)) == %{
               start_date: "Tue, September 01, 2026",
               end_date: "Thu, December 31, 2026",
               active: :inactive,
               servers_enabled: :inactive,
               teacher_ssh_public_keys_count: "0"
             }
    end

    test "navigate away when the class is deleted over PubSub", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Gone")
      stub_class_page(auth, class: class, server_group: server_group)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      :ok = Course.PubSub.publish_class_deleted(class)

      flash = assert_redirect(view, "/admin/classes")

      assert redirect_notifications(flash) == [
               {:success, gettext("Deleted class {class}", class: "Gone")}
             ]
    end
  end

  test "accessing the class page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, "/admin/classes/#{UUID.generate()}")
  end

  defp build_class_and_group(class_attrs \\ []) do
    class = CourseFactory.build(:class, Keyword.merge([teacher_ssh_public_keys: []], class_attrs))

    # The detail page fetches the class and its mirror server group by the same
    # route ID, and they share the same expected-server-properties row, so the
    # group must carry the class ID/version and the matching properties ID for
    # the `class_updated` refresh to apply in memory.
    server_group =
      ServersFactory.build(:server_group,
        id: class.id,
        version: class.version,
        expected_server_properties:
          ServersFactory.build(:server_properties, id: class.expected_server_properties.id)
      )

    {class, server_group}
  end

  # The detail page reads from the Course and Servers contexts on every render,
  # and its eagerly-rendered child dialogs read again (the delete and import
  # dialogs both list the class students), so these ambient reads fire a
  # variable number of times across the disconnected/connected mounts and any
  # later re-render. They are stubbed so each test can `expect` only the one
  # mutation it asserts.
  defp stub_class_page(auth, opts) do
    class = Keyword.fetch!(opts, :class)
    server_group = Keyword.fetch!(opts, :server_group)
    students = Keyword.get(opts, :students, [])
    server_ids = Keyword.get(opts, :server_ids, [])

    stub(Course.ContextMock, :fetch_class, fn ^auth, _id -> {:ok, class} end)
    stub(Servers.ContextMock, :fetch_server_group, fn ^auth, _id -> {:ok, server_group} end)

    stub(Servers.ContextMock, :watch_server_ids, fn ^auth, _group ->
      {:ok, MapSet.new(server_ids), fn ids, _event -> ids end}
    end)

    stub(Course.ContextMock, :list_students, fn ^auth, _class -> students end)

    :ok
  end

  # Projects the class data display (the page's only `<dl>`) to its meaningful
  # values; the active/servers-enabled icons project to `:active`/`:inactive`.
  defp class_detail(html) do
    [start_dd, end_dd, active_dd, servers_dd, keys_dd] = find_html_elements(html, "dl dd")

    %{
      start_date: html_element_text(start_dd),
      end_date: html_element_text(end_dd),
      active: icon_state(active_dd),
      servers_enabled: icon_state(servers_dd),
      teacher_ssh_public_keys_count: html_element_text(keys_dd)
    }
  end

  defp icon_state(element),
    do: if(find_html_elements(element, ".text-success") != [], do: :active, else: :inactive)

  defp class_form_errors(html, form_id),
    do:
      html
      |> find_html_elements("##{form_id} p.text-error")
      |> Enum.map(&html_element_text/1)

  defp delete_button_disabled?(html, class) do
    [button] =
      find_html_elements(html, ~s(#delete-class-dialog-#{class.id} button[phx-click="delete"]))

    html_element_attribute(button, "disabled") != nil
  end

  defp delete_class_dialog_text(html, class, selector) do
    case find_html_elements(html, "#delete-class-dialog-#{class.id} #{selector}") do
      [element] -> html_element_text(element)
      [] -> nil
    end
  end

  defp redirect_notifications(flash),
    do:
      flash
      |> Map.values()
      |> Enum.map(fn notification -> {notification.type, notification.message} end)
end
