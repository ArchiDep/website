defmodule ArchiDepWeb.Admin.Classes.ClassLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Servers
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDepWeb.Admin.Classes.StudentForm
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

      stub_class_page_calls(auth, class: class, server_group: server_group)

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
      stub_class_page_calls(auth, class: class, server_group: server_group)
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
             |> form_errors("edit-class-form") == ["is invalid"]

      assert view
             |> form("#edit-class-form", class: %{name: "Good"})
             |> render_change()
             |> form_errors("edit-class-form") == []
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

      stub_class_page_calls(auth, class: class, server_group: server_group)
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

      assert_flash_notification(
        view,
        :success,
        gettext("Updated class {class}", class: "Updated Class")
      )
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

      stub_class_page_calls(auth, class: class, server_group: server_group)
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

      assert_flash_notification(
        view,
        :success,
        gettext("Updated class {class}", class: "Cleared")
      )
    end

    test "render errors when the class cannot be updated", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original")
      stub_class_page_calls(auth, class: class, server_group: server_group)
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
             |> form_errors("edit-class-form") == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "add a teacher SSH public key field", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original", teacher_ssh_public_keys: [])
      stub_class_page_calls(auth, class: class, server_group: server_group)

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

      stub_class_page_calls(auth,
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

      stub_class_page_calls(auth,
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

      stub_class_page_calls(auth,
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

      stub_class_page_calls(auth,
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

      stub_class_page_calls(auth,
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

      assert_flash_notification(
        view,
        :error,
        gettext(
          "Class {class} cannot be deleted because at least one server is linked to it.",
          class: "Doomed"
        )
      )

      delete_dialog_id = "#delete-class-dialog-#{class.id}"
      assert_push_event(view, "execute-action", %{to: ^delete_dialog_id, action: "close"})
    end
  end

  describe "the edit expected-server-properties dialog" do
    setup :register_and_log_in_root

    test "validate the edited properties against the context", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Original")
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id
      form_id = "edit-class-expected-server-properties-dialog-#{class.id}-form"

      invalid =
        %ExpectedServerProperties{}
        |> Changeset.cast(%{cpus: 1}, [:cpus])
        |> Changeset.add_error(:cpus, "is invalid")

      valid = Changeset.cast(%ExpectedServerProperties{}, %{cpus: 2}, [:cpus])

      expect(
        Course.ContextMock,
        :validate_expected_server_properties_for_class,
        fn ^auth, ^class_id, %{cpus: 1} -> {:ok, invalid} end
      )

      expect(
        Course.ContextMock,
        :validate_expected_server_properties_for_class,
        fn ^auth, ^class_id, %{cpus: 2} -> {:ok, valid} end
      )

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("##{form_id}", expected_server_properties: %{cpus: "1"})
             |> render_change()
             |> form_errors(form_id) == ["is invalid"]

      assert view
             |> form("##{form_id}", expected_server_properties: %{cpus: "2"})
             |> render_change()
             |> form_errors(form_id) == []
    end

    test "update the expected server properties from a full submission", %{
      conn: conn,
      auth: auth
    } do
      {class, server_group} = build_class_and_group(name: "Crypto 101")
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id
      dialog_id = "edit-class-expected-server-properties-dialog-#{class.id}"

      updated = CourseFactory.build(:expected_server_properties)
      test_pid = self()

      expect(
        Course.ContextMock,
        :update_expected_server_properties_for_class,
        fn ^auth, ^class_id, data ->
          send(test_pid, {:updated_with, data})
          {:ok, updated}
        end
      )

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("##{dialog_id}-form",
        expected_server_properties: %{
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
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
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

      push_to = "##{dialog_id}"
      assert_push_event(view, "execute-action", %{to: ^push_to, action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Updated expected server properties for {class}", class: "Crypto 101")
      )
    end

    test "update the expected server properties clearing every field", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          name: "Crypto 101",
          expected_server_properties:
            CourseFactory.build(:expected_server_properties,
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
            )
        )

      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id
      dialog_id = "edit-class-expected-server-properties-dialog-#{class.id}"

      updated = CourseFactory.build(:expected_server_properties)
      test_pid = self()

      expect(
        Course.ContextMock,
        :update_expected_server_properties_for_class,
        fn ^auth, ^class_id, data ->
          send(test_pid, {:updated_with, data})
          {:ok, updated}
        end
      )

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("##{dialog_id}-form",
        expected_server_properties: %{
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
      )
      |> render_submit()

      assert_receive {:updated_with, data}

      assert data == %{
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

      assert_flash_notification(
        view,
        :success,
        gettext("Updated expected server properties for {class}", class: "Crypto 101")
      )
    end

    test "render errors when the properties cannot be updated", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group(name: "Crypto 101")
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id
      form_id = "edit-class-expected-server-properties-dialog-#{class.id}-form"

      {:error, errored} =
        %ExpectedServerProperties{}
        |> Changeset.cast(%{cpus: 99}, [:cpus])
        |> Changeset.add_error(:cpus, "must be between 1 and 16")
        |> Changeset.apply_action(:update)

      expect(
        Course.ContextMock,
        :update_expected_server_properties_for_class,
        fn ^auth, ^class_id, _data -> {:error, errored} end
      )

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("##{form_id}", expected_server_properties: %{cpus: "99"})
             |> render_submit()
             |> form_errors(form_id) == ["must be between 1 and 16"]

      assert_flash_notification(view, :error, gettext("The form is invalid."))

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "show the edit trigger when the class has expected properties", %{conn: conn, auth: auth} do
      {class, server_group} =
        build_class_and_group(
          expected_server_properties: CourseFactory.build(:expected_server_properties, cpus: 4)
        )

      stub_class_page_calls(auth, class: class, server_group: server_group)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert has_element?(view, ".edit-expected-server-properties")
      refute has_element?(view, ".define-expected-server-properties")
    end

    test "show the define trigger when the class has no expected properties", %{
      conn: conn,
      auth: auth
    } do
      {class, server_group} =
        build_class_and_group(
          expected_server_properties: ExpectedServerProperties.blank(UUID.generate())
        )

      stub_class_page_calls(auth, class: class, server_group: server_group)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert has_element?(view, ".define-expected-server-properties")
      refute has_element?(view, ".edit-expected-server-properties")
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

      stub_class_page_calls(auth, class: class, server_group: server_group)

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
      stub_class_page_calls(auth, class: class, server_group: server_group)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      :ok = Course.PubSub.publish_class_deleted(class)

      flash = assert_redirect(view, "/admin/classes")

      assert redirect_notifications(flash) == [
               {:success, gettext("Deleted class {class}", class: "Gone")}
             ]
    end
  end

  describe "the students table" do
    setup :register_and_log_in_root

    test "render the students of the class", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      registered_id = UUID.generate()

      registered =
        CourseFactory.build(:student,
          id: registered_id,
          class_id: class.id,
          name: "Alice",
          academic_class: "INF-1",
          email: "alice@example.org",
          username: "alice",
          username_confirmed: true,
          active: true,
          user: CourseFactory.build(:user, student: nil, student_id: registered_id)
        )

      unregistered =
        CourseFactory.build(:student,
          class_id: class.id,
          name: "Bob",
          academic_class: nil,
          email: "bob@example.org",
          username: "bob",
          username_confirmed: false,
          active: false,
          user: nil
        )

      stub_class_page_calls(auth,
        class: class,
        server_group: server_group,
        students: [registered, unregistered]
      )

      {:ok, _view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == %{
               students: %{
                 registered: "1/2 registered",
                 empty_message: nil,
                 rows: [
                   %{
                     name: "Alice",
                     academic_class: "INF-1",
                     email: "alice@example.org",
                     username: "alice",
                     active: :active,
                     user_account: "alice"
                   },
                   %{
                     name: "Bob",
                     academic_class: "-",
                     email: "bob@example.org",
                     username: "bob (#{gettext("suggested")})",
                     active: :inactive,
                     user_account: gettext("Not registered yet")
                   }
                 ]
               },
               delete_blocked: false
             }
    end

    test "render an empty state when the class has no students", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      stub_class_page_calls(auth, class: class, server_group: server_group, students: [])

      {:ok, _view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == %{
               students: %{
                 registered: nil,
                 rows: [],
                 empty_message: gettext("No students in this class")
               },
               delete_blocked: false
             }
    end
  end

  describe "the new student dialog" do
    setup :register_and_log_in_root

    test "validate the new student against the context", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id

      invalid =
        %StudentForm{}
        |> Changeset.cast(%{"name" => "Bad"}, [:name])
        |> Changeset.add_error(:name, "is invalid")

      valid = Changeset.cast(%StudentForm{}, %{"name" => "Good"}, [:name])

      expect(Course.ContextMock, :validate_student, fn ^auth, ^class_id, %{name: "Bad"} ->
        {:ok, invalid}
      end)

      expect(Course.ContextMock, :validate_student, fn ^auth, ^class_id, %{name: "Good"} ->
        {:ok, valid}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("#new-student-form", student: %{name: "Bad"})
             |> render_change()
             |> form_errors("new-student-form") == ["is invalid"]

      assert view
             |> form("#new-student-form", student: %{name: "Good"})
             |> render_change()
             |> form_errors("new-student-form") == []
    end

    test "create a student from a minimal submission", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id

      created = CourseFactory.build(:student, name: "Carol")
      test_pid = self()

      expect(Course.ContextMock, :create_student, fn ^auth, ^class_id, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("#new-student-form",
        student: %{
          name: "Carol",
          email: "carol@example.org",
          username: "carol",
          domain: "carol.archidep.ch",
          active: "true",
          servers_enabled: "false"
        }
      )
      |> render_submit()

      assert_receive {:created_with, data}

      assert data == %{
               name: "Carol",
               email: "carol@example.org",
               academic_class: nil,
               username: "carol",
               domain: "carol.archidep.ch",
               active: true,
               servers_enabled: false
             }

      assert_push_event(view, "execute-action", %{to: "#new-student-dialog", action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("Created student {student}", student: "Carol")
      )
    end

    test "create a student from a full submission", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id

      created = CourseFactory.build(:student, name: "Dave")
      test_pid = self()

      expect(Course.ContextMock, :create_student, fn ^auth, ^class_id, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("#new-student-form",
        student: %{
          name: "Dave",
          email: "dave@example.org",
          academic_class: "INF-2",
          username: "dave",
          domain: "dave.archidep.ch",
          active: "true",
          servers_enabled: "true"
        }
      )
      |> render_submit()

      assert_receive {:created_with, data}

      assert data == %{
               name: "Dave",
               email: "dave@example.org",
               academic_class: "INF-2",
               username: "dave",
               domain: "dave.archidep.ch",
               active: true,
               servers_enabled: true
             }

      assert_flash_notification(
        view,
        :success,
        gettext("Created student {student}", student: "Dave")
      )
    end

    test "render errors when the student cannot be created", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      stub_class_page_calls(auth, class: class, server_group: server_group)
      class_id = class.id

      {:error, errored} =
        %StudentForm{}
        |> Changeset.cast(%{"username" => "taken"}, [:username])
        |> Changeset.add_error(:username, "has already been taken")
        |> Changeset.apply_action(:insert)

      expect(Course.ContextMock, :create_student, fn ^auth, ^class_id, _data ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("#new-student-form", student: %{username: "taken"})
             |> render_submit()
             |> form_errors("new-student-form") == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end
  end

  describe "student live updates" do
    setup :register_and_log_in_root

    test "reload the students when a student is updated over PubSub", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      alice = listed_student(class, "Alice", "alice@example.org")
      bob = listed_student(class, "Bob", "bob@example.org")

      {:ok, students} = Agent.start_link(fn -> [alice] end)
      stub_class_page_calls(auth, class: class, server_group: server_group)
      stub(Course.ContextMock, :list_students, fn ^auth, _class -> Agent.get(students, & &1) end)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == listed_class_page(class, "0/1 registered", ["Alice"])

      Agent.update(students, fn _state -> [alice, bob] end)
      :ok = Course.PubSub.publish_student_updated(%{alice | name: "Alice"})

      wait_for_socket_assigns!(
        view,
        fn assigns -> length(assigns.students) == 2 end,
        "students reloaded"
      )

      assert class_page(render(view), class) ==
               listed_class_page(class, "0/2 registered", ["Alice", "Bob"])
    end

    test "reload the students when students are imported over PubSub", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      alice = listed_student(class, "Alice", "alice@example.org")

      {:ok, students} = Agent.start_link(fn -> [] end)
      stub_class_page_calls(auth, class: class, server_group: server_group)
      stub(Course.ContextMock, :list_students, fn ^auth, _class -> Agent.get(students, & &1) end)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == empty_class_page(class)

      Agent.update(students, fn _state -> [alice] end)
      :ok = Course.PubSub.publish_students_imported(class, [alice])

      wait_for_socket_assigns!(
        view,
        fn assigns -> length(assigns.students) == 1 end,
        "students reloaded"
      )

      assert class_page(render(view), class) ==
               listed_class_page(class, "0/1 registered", ["Alice"])
    end

    test "reload the students when a preregistered user is updated over PubSub", %{
      conn: conn,
      auth: auth
    } do
      {class, server_group} = build_class_and_group()
      alice = listed_student(class, "Alice", "alice@example.org")

      {:ok, students} = Agent.start_link(fn -> [] end)
      stub_class_page_calls(auth, class: class, server_group: server_group)
      stub(Course.ContextMock, :list_students, fn ^auth, _class -> Agent.get(students, & &1) end)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == empty_class_page(class)

      Agent.update(students, fn _state -> [alice] end)

      :ok =
        Accounts.PubSub.publish_preregistered_user_updated(
          AccountsFactory.build(:preregistered_user, group_id: class.id)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> length(assigns.students) == 1 end,
        "students reloaded"
      )

      assert class_page(render(view), class) ==
               listed_class_page(class, "0/1 registered", ["Alice"])
    end

    test "track a created server so the class can no longer be deleted", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()

      stub_class_page_calls(auth, class: class, server_group: server_group, students: [])

      stub(Servers.ContextMock, :watch_server_ids, fn ^auth, group ->
        :ok = Servers.PubSub.subscribe_server_group_servers(group.id)
        {:ok, MapSet.new(), &server_ids_reducer/2}
      end)

      {:ok, view, html} = live(conn, "/admin/classes/#{class.id}")

      assert class_page(html, class) == empty_class_page(class)

      server = ServersFactory.build(:server, group_id: server_group.id)
      :ok = Servers.PubSub.publish_server_created(server)

      wait_for_socket_assigns!(
        view,
        fn assigns -> assigns.server_ids |> elem(0) |> MapSet.size() == 1 end,
        "server tracked"
      )

      assert class_page(render(view), class) == %{empty_class_page(class) | delete_blocked: true}
    end
  end

  describe "the import students dialog" do
    setup :register_and_log_in_root

    test "render the parsed CSV with column detection and per-row state", %{
      conn: conn,
      auth: auth
    } do
      {class, server_group} = build_class_and_group()
      write_import_csv(class, "Name,Email\nAlice,alice@example.org\nBob,bob@example.org\n")

      existing = CourseFactory.build(:student, class_id: class.id, email: "alice@example.org")

      stub_class_page_calls(auth,
        class: class,
        server_group: server_group,
        students: [existing]
      )

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      # A valid domain clears the only initial error, so the per-row state
      # reflects the new/existing classification rather than "invalid".
      html =
        view
        |> form("#import-students",
          import_students: %{name_column: "Name", email_column: "Email", domain: "archidep.ch"}
        )
        |> render_change()

      assert import_table(html) == %{
               columns: ["Name", "Email"],
               states: [gettext("existing"), gettext("new")]
             }
    end

    test "validate rejects a name column that contains emails", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      write_import_csv(class, "Name,Email\nAlice,alice@example.org\nBob,bob@example.org\n")
      stub_class_page_calls(auth, class: class, server_group: server_group, students: [])

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      assert view
             |> form("#import-students",
               import_students: %{
                 name_column: "Email",
                 email_column: "Email",
                 domain: "archidep.ch"
               }
             )
             |> render_change()
             |> form_errors("import-students") == [
               gettext("this column looks like it contains emails, not names")
             ]
    end

    test "import the parsed students", %{conn: conn, auth: auth} do
      {class, server_group} = build_class_and_group()
      write_import_csv(class, "Name,Email\nAlice,alice@example.org\nBob,bob@example.org\n")
      stub_class_page_calls(auth, class: class, server_group: server_group, students: [])
      class_id = class.id

      imported = [
        CourseFactory.build(:student, class_id: class.id),
        CourseFactory.build(:student, class_id: class.id)
      ]

      test_pid = self()

      expect(Course.ContextMock, :import_students, fn ^auth, ^class_id, data ->
        send(test_pid, {:imported_with, data})
        {:ok, imported}
      end)

      {:ok, view, _html} = live(conn, "/admin/classes/#{class.id}")

      view
      |> form("#import-students",
        import_students: %{
          name_column: "Name",
          email_column: "Email",
          academic_class: "Sec 2026",
          domain: "archidep.ch"
        }
      )
      |> render_change()

      view |> form("#import-students") |> render_submit()

      assert_receive {:imported_with, data}

      assert data == %{
               academic_class: "Sec 2026",
               domain: "archidep.ch",
               students: [
                 %{name: "Alice", email: "alice@example.org"},
                 %{name: "Bob", email: "bob@example.org"}
               ]
             }

      assert_push_event(view, "execute-action", %{to: "#import-students-dialog", action: "close"})

      assert_flash_notification(
        view,
        :success,
        gettext("{count, plural, =1 {1 student} other {# students}} imported", count: 2)
      )
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
  defp stub_class_page_calls(auth, opts) do
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

  defp form_errors(html, form_id),
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

  # Projects the whole page region this chunk owns: the students section (the
  # registered count, every row, and the empty-state message) and whether the
  # delete-class affordance is blocked by linked servers.
  defp class_page(html, class) do
    %{
      students: %{
        registered: students_registered(html),
        rows: students_table(html),
        empty_message: empty_students_message(html)
      },
      delete_blocked: delete_button_disabled?(html, class)
    }
  end

  defp empty_class_page(_class),
    do: %{
      students: %{
        registered: nil,
        rows: [],
        empty_message: gettext("No students in this class")
      },
      delete_blocked: false
    }

  defp listed_class_page(_class, registered, names),
    do: %{
      students: %{
        registered: registered,
        rows: Enum.map(names, &listed_row(&1, "#{String.downcase(&1)}@example.org")),
        empty_message: nil
      },
      delete_blocked: false
    }

  # Projects each student row (keyed by its `student-<id>` row) to its
  # meaningful cells; the active icon projects to `:active`/`:inactive`.
  defp students_table(html) do
    html
    |> find_html_elements("tr[id^='student-']")
    |> Enum.map(fn row ->
      [name, academic_class, email, username, active, user_account] =
        find_html_elements(row, "td")

      %{
        name: html_element_text(name),
        academic_class: html_element_text(academic_class),
        email: html_element_text(email),
        username: html_element_text(username),
        active: icon_state(active),
        user_account: html_element_text(user_account)
      }
    end)
  end

  # A fully-pinned unregistered student paired with `listed_row/2`, so the
  # reload tests can assert the whole rendered table by equality.
  defp listed_student(class, name, email),
    do:
      CourseFactory.build(:student,
        class_id: class.id,
        name: name,
        academic_class: "INF-1",
        email: email,
        username: String.downcase(name),
        username_confirmed: true,
        active: true,
        user: nil
      )

  defp listed_row(name, email),
    do: %{
      name: name,
      academic_class: "INF-1",
      email: email,
      username: String.downcase(name),
      active: :active,
      user_account: gettext("Not registered yet")
    }

  defp students_registered(html) do
    case find_html_elements(html, "h3 small") do
      [small] -> html_element_text(small)
      [] -> nil
    end
  end

  defp empty_students_message(html) do
    case find_html_elements(html, "table tbody td[colspan]") do
      [td] -> html_element_text(td)
      [] -> nil
    end
  end

  # Mirrors the contract of the real `watch_server_ids` reducer (it adds created
  # server IDs and drops deleted ones), so the page's server PubSub handler can
  # be driven through a real broadcast.
  defp server_ids_reducer(ids, {:server_created, server}), do: MapSet.put(ids, server.id)
  defp server_ids_reducer(ids, {:server_deleted, server}), do: MapSet.delete(ids, server.id)
  defp server_ids_reducer(ids, {:server_updated, _server}), do: ids

  # The import dialog parses the uploaded CSV from disk on mount, so writing the
  # file at the path it reads drives the parsing/classification/import flow
  # without the live upload machinery. The class-specific directory is removed
  # after the test.
  defp write_import_csv(class, content) do
    path = import_csv_path(class)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)

    on_exit(fn ->
      File.rm_rf!(Path.join([uploads_directory(), "students", "classes", class.id]))
    end)

    :ok
  end

  defp import_csv_path(class),
    do: Path.join([uploads_directory(), "students", "classes", class.id, "import-students.csv"])

  defp uploads_directory,
    do:
      :archidep
      |> Application.fetch_env!(ArchiDepWeb.Endpoint)
      |> Keyword.fetch!(:uploads_directory)

  defp import_table(html),
    do: %{columns: import_columns(html), states: import_states(html)}

  defp import_columns(html),
    do:
      html
      |> find_html_elements("#import-students-dialog table thead th")
      |> Enum.map(&html_element_text/1)
      |> Enum.drop(-1)

  defp import_states(html),
    do:
      html
      |> find_html_elements("#import-students-dialog tbody tr")
      |> Enum.map(fn row ->
        [badge] = find_html_elements(row, "td:last-child .badge")
        html_element_text(badge)
      end)
end
