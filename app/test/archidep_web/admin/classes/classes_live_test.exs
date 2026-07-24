defmodule ArchiDepWeb.Admin.Classes.ClassesLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.UseCases.ReadClasses
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias Ecto.Changeset

  @path "/admin/classes"
  @new_class_dialog_id "new-class-dialog"
  @new_class_form_id "new-class-form"

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    test "render the classes page over a static (disconnected) request", %{
      conn: conn,
      auth: auth
    } do
      solo =
        CourseFactory.build(:class,
          name: "Solo",
          active: true,
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31]
        )

      expect_classes_page_calls(auth, mounts: 1, classes: [solo])

      html =
        conn
        |> get(@path)
        |> html_response(200)

      assert_html_title(html, "Classes · Admin · ArchiDep")

      assert classes_table(html) == [
               {"Solo", "From Tue, September 01, 2026 until Thu, December 31, 2026", :active}
             ]
    end
  end

  describe "the classes list" do
    setup :register_and_log_in_root

    test "render every class returned by the context", %{conn: conn, auth: auth} do
      gamma =
        CourseFactory.build(:class,
          name: "Gamma",
          active: false,
          start_date: ~D[2026-01-01],
          end_date: ~D[2026-03-31]
        )

      alpha =
        CourseFactory.build(:class,
          name: "Alpha",
          active: true,
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31]
        )

      beta =
        CourseFactory.build(:class,
          name: "Beta",
          active: true,
          start_date: nil,
          end_date: ~D[2026-06-30]
        )

      delta =
        CourseFactory.build(:class,
          name: "Delta",
          active: true,
          start_date: ~D[2026-09-01],
          end_date: nil
        )

      epsilon =
        CourseFactory.build(:class, name: "Epsilon", active: true, start_date: nil, end_date: nil)

      expect_classes_page_calls(auth, classes: [gamma, alpha, beta, delta, epsilon])

      {:ok, _view, html} = live(conn, @path)

      assert classes_table(html) == [
               {"Gamma", "From Thu, January 01, 2026 until Tue, March 31, 2026", :inactive},
               {"Alpha", "From Tue, September 01, 2026 until Thu, December 31, 2026", :active},
               {"Beta", "Until Tue, June 30, 2026", :active},
               {"Delta", "From Tue, September 01, 2026", :active},
               {"Epsilon", "", :active}
             ]
    end

    test "render an empty state when there are no classes", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      {:ok, view, html} = live(conn, @path)

      assert classes_table(html) == []
      assert has_element?(view, "td", "No classes")
    end
  end

  describe "live list updates" do
    setup :register_and_log_in_root

    test "add a row when a class is created", %{conn: conn, auth: auth} do
      existing =
        CourseFactory.build(:class,
          name: "Existing",
          active: true,
          start_date: nil,
          end_date: ~D[2026-06-30]
        )

      expect_classes_page_calls(auth, classes: [existing])

      {:ok, view, html} = live(conn, @path)
      assert classes_table(html) == [{"Existing", "Until Tue, June 30, 2026", :active}]

      created =
        CourseFactory.build(:class,
          name: "Newbie",
          active: true,
          start_date: nil,
          end_date: ~D[2026-12-31]
        )

      # The created broadcast carries only the curated event; the list refresher
      # fetches the full view through the context boundary on first sighting.
      created_id = created.id

      stub(Course.ContextMock, :fetch_class, fn ^auth, ^created_id ->
        {:ok, ClassView.from(created)}
      end)

      :ok =
        Course.PubSub.publish_class_created(
          ClassCreated.new(created),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Enum.any?(assigns.classes, &(&1.id == created.id)) end,
        "created class added"
      )

      assert classes_table(render(view)) == [
               {"Newbie", "Until Thu, December 31, 2026", :active},
               {"Existing", "Until Tue, June 30, 2026", :active}
             ]
    end

    test "remove a row when a class is deleted", %{conn: conn, auth: auth} do
      keeper =
        CourseFactory.build(:class,
          name: "Keeper",
          active: true,
          start_date: nil,
          end_date: ~D[2026-06-30]
        )

      victim =
        CourseFactory.build(:class,
          name: "Victim",
          active: true,
          start_date: nil,
          end_date: ~D[2026-12-31]
        )

      expect_classes_page_calls(auth, classes: [victim, keeper])

      {:ok, view, html} = live(conn, @path)

      assert classes_table(html) == [
               {"Victim", "Until Thu, December 31, 2026", :active},
               {"Keeper", "Until Tue, June 30, 2026", :active}
             ]

      :ok =
        Course.PubSub.publish_class_deleted(
          ClassDeleted.new(victim),
          EventsFactory.build(:event_reference)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Enum.any?(assigns.classes, &(&1.id == victim.id)) end,
        "deleted class removed"
      )

      assert classes_table(render(view)) == [{"Keeper", "Until Tue, June 30, 2026", :active}]
    end

    test "re-render a row when a class is updated", %{conn: conn, auth: auth} do
      class =
        CourseFactory.build(:class,
          name: "Original",
          active: true,
          start_date: nil,
          end_date: ~D[2026-06-30]
        )

      expect_classes_page_calls(auth, classes: [class])

      {:ok, view, html} = live(conn, @path)
      assert classes_table(html) == [{"Original", "Until Tue, June 30, 2026", :active}]

      updated = %{class | name: "Renamed", version: class.version + 1}

      :ok =
        Course.PubSub.publish_class_updated(
          updated,
          ClassUpdated.new(updated),
          EventsFactory.build(:event_reference, version: updated.version)
        )

      wait_for_socket_assigns!(
        view,
        fn assigns ->
          Enum.any?(assigns.classes, &(&1.id == class.id and &1.name == "Renamed"))
        end,
        "updated class re-rendered"
      )

      assert classes_table(render(view)) == [{"Renamed", "Until Tue, June 30, 2026", :active}]
    end
  end

  describe "creating a class" do
    setup :register_and_log_in_root

    test "render the create-class dialog", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "##{@new_class_dialog_id}")
      assert has_element?(view, "##{@new_class_form_id}")
    end

    test "validate the new class against the context", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      invalid = Changeset.add_error(Changeset.change(%Class{}), :name, "is invalid")
      valid = Changeset.change(%Class{})

      expect(Course.ContextMock, :validate_class, fn ^auth, %{name: "Bad"} -> invalid end)
      expect(Course.ContextMock, :validate_class, fn ^auth, %{name: "Good"} -> valid end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("##{@new_class_form_id}", class: %{name: "Bad"})
             |> render_change()
             |> class_form_errors() == ["is invalid"]

      assert view
             |> form("##{@new_class_form_id}", class: %{name: "Good"})
             |> render_change()
             |> class_form_errors() == []
    end

    test "create a class from a minimal submission", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      created = CourseFactory.build(:class, name: "New Class")
      test_pid = self()

      expect(Course.ContextMock, :create_class, fn ^auth, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("##{@new_class_form_id}", class: %{name: "New Class"})
             |> render_submit()
             |> class_form_errors() == []

      assert_receive {:created_with, data}

      assert data == %{
               name: "New Class",
               start_date: nil,
               end_date: nil,
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               ssh_exercise_vm_md5_host_key_fingerprints: nil,
               ssh_exercise_vm_sha256_host_key_fingerprints: nil
             }

      assert_push_event(view, "execute-action", %{
        to: "##{@new_class_dialog_id}",
        action: "close"
      })

      notification = gettext("Created class {class}", class: "New Class")

      assert_flash_notification(view, :success, notification)
    end

    test "create a class from a full submission", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      created = CourseFactory.build(:class, name: "Full Class")
      test_pid = self()

      expect(Course.ContextMock, :create_class, fn ^auth, data ->
        send(test_pid, {:created_with, data})
        {:ok, created}
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> element(~s(##{@new_class_form_id} button[phx-click="add_teacher_ssh_public_key"]))
      |> render_click()

      view
      |> form("##{@new_class_form_id}",
        class: %{
          name: "Full Class",
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

      assert_receive {:created_with, data}

      assert data == %{
               name: "Full Class",
               start_date: ~D[2026-09-01],
               end_date: ~D[2026-12-31],
               active: true,
               servers_enabled: true,
               teacher_ssh_public_keys: ["ssh-ed25519 AAAAKEY"],
               ssh_exercise_vm_md5_host_key_fingerprints: "11:22:33:44",
               ssh_exercise_vm_sha256_host_key_fingerprints: "aa:bb:cc:dd"
             }
    end

    test "show an error when the class cannot be created", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      {:error, errored} =
        %Class{}
        |> Changeset.change()
        |> Changeset.add_error(:name, "has already been taken")
        |> Changeset.apply_action(:insert)

      expect(Course.ContextMock, :create_class, fn ^auth, %{name: "Taken"} ->
        {:error, errored}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("##{@new_class_form_id}", class: %{name: "Taken"})
             |> render_submit()
             |> class_form_errors() == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "add a teacher SSH public key field", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      {:ok, view, _html} = live(conn, @path)

      refute has_element?(
               view,
               ~s(##{@new_class_form_id} input[name^="class[teacher_ssh_public_keys]"])
             )

      assert view
             |> element(~s(##{@new_class_form_id} button[phx-click="add_teacher_ssh_public_key"]))
             |> render_click()
             |> find_html_elements(
               ~s(##{@new_class_form_id} input[type="text"][name^="class[teacher_ssh_public_keys]"])
             )
             |> length() == 1
    end

    test "reset the form when the dialog is closed", %{conn: conn, auth: auth} do
      expect_classes_page_calls(auth, classes: [])

      expect(Course.ContextMock, :validate_class, fn ^auth, _data ->
        Changeset.change(%Class{})
      end)

      {:ok, view, _html} = live(conn, @path)

      view
      |> element(~s(##{@new_class_form_id} button[phx-click="add_teacher_ssh_public_key"]))
      |> render_click()

      populated =
        view
        |> form("##{@new_class_form_id}",
          class: %{
            name: "Typed",
            start_date: "2026-09-01",
            end_date: "2026-12-31",
            active: "true",
            servers_enabled: "true",
            teacher_ssh_public_keys: %{"0" => %{value: "ssh-key"}},
            ssh_exercise_vm_md5_host_key_fingerprints: "md5",
            ssh_exercise_vm_sha256_host_key_fingerprints: "sha256"
          }
        )
        |> render_change()

      assert form_values(populated) == %{
               name: "Typed",
               start_date: "2026-09-01",
               end_date: "2026-12-31",
               active: true,
               servers_enabled: true,
               teacher_ssh_public_keys: ["ssh-key"],
               md5_fingerprints: "md5",
               sha256_fingerprints: "sha256"
             }

      reset =
        view
        |> element(~s(##{@new_class_dialog_id} form.modal-backdrop))
        |> render_click()

      assert form_values(reset) == %{
               name: "",
               start_date: "",
               end_date: "",
               active: false,
               servers_enabled: false,
               teacher_ssh_public_keys: [],
               md5_fingerprints: "",
               sha256_fingerprints: ""
             }
    end
  end

  test "accessing the classes page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  # The classes page reads the list of classes on every mount, and a LiveView
  # mounts twice (the disconnected HTTP render, then the connected socket), so
  # the read is expected twice; pass `mounts: 1` for a static `get/2` request,
  # which mounts once.
  defp expect_classes_page_calls(auth, opts) do
    mounts = Keyword.get(opts, :mounts, 2)
    classes = Keyword.fetch!(opts, :classes)

    expect(Course.ContextMock, :list_classes, mounts, fn ^auth ->
      Enum.map(classes, &ClassView.from/1)
    end)

    # The page keeps the classes list current through the Course boundary; route
    # those calls to the real read-model plumbing so a real broadcast still
    # drives the re-render.
    stub(Course.ContextMock, :subscribe_classes, &ReadClasses.subscribe_classes/0)
    stub(Course.ContextMock, :refresh_classes, &ReadClasses.refresh_classes/3)

    :ok
  end

  defp classes_table(html),
    do: html |> find_html_elements(~s(tbody tr[id^="class-"])) |> Enum.map(&project_class_row/1)

  defp project_class_row(row) do
    [name_td, _start_td, _end_td, active_td] = find_html_elements(row, "td")

    # The date columns duplicate their value across responsive (mobile/desktop)
    # markup; the mobile cell carries the whole window as one string, so it is
    # the single meaningful projection of the date range.
    [dates] = find_html_elements(row, "td:nth-child(2) span:first-child")

    active = if find_html_elements(active_td, ".text-success") != [], do: :active, else: :inactive

    {html_element_text(name_td), html_element_text(dates), active}
  end

  # Projects the editable values of the new-class form, so a test can pin the
  # whole form state (e.g. before vs. after a reset) by equality.
  defp form_values(html) do
    %{
      name: form_input_value(html, ~s(input[name="class[name]"])),
      start_date: form_input_value(html, ~s(input[name="class[start_date]"])),
      end_date: form_input_value(html, ~s(input[name="class[end_date]"])),
      active: form_checkbox_checked?(html, ~s(input[type="checkbox"][name="class[active]"])),
      servers_enabled:
        form_checkbox_checked?(html, ~s(input[type="checkbox"][name="class[servers_enabled]"])),
      teacher_ssh_public_keys:
        html
        |> find_html_elements(
          ~s(##{@new_class_form_id} input[type="text"][name^="class[teacher_ssh_public_keys]"])
        )
        |> Enum.map(&(html_element_attribute(&1, "value") || "")),
      md5_fingerprints:
        form_textarea_value(
          html,
          ~s(textarea[name="class[ssh_exercise_vm_md5_host_key_fingerprints]"])
        ),
      sha256_fingerprints:
        form_textarea_value(
          html,
          ~s(textarea[name="class[ssh_exercise_vm_sha256_host_key_fingerprints]"])
        )
    }
  end

  defp form_input_value(html, selector) do
    [element] = find_html_elements(html, "##{@new_class_form_id} #{selector}")
    html_element_attribute(element, "value") || ""
  end

  defp form_textarea_value(html, selector) do
    [element] = find_html_elements(html, "##{@new_class_form_id} #{selector}")
    html_element_text(element)
  end

  defp form_checkbox_checked?(html, selector) do
    [element] = find_html_elements(html, "##{@new_class_form_id} #{selector}")
    html_element_attribute(element, "checked") != nil
  end

  defp class_form_errors(html),
    do:
      html
      |> find_html_elements("##{@new_class_form_id} p.text-error")
      |> Enum.map(&html_element_text/1)
end
