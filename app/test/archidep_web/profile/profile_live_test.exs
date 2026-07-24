defmodule ArchiDepWeb.Profile.ProfileLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.Events.StudentUpdated
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Course.UseCases.ReadStudents
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.EventsFactory
  alias Ecto.Changeset

  @path "/profile"
  @current_sessions_table_id "current-sessions"
  @change_username_dialog_id "change-username-dialog"
  @registered_at ~U[2024-01-15 09:30:00Z]
  @registration_row {"Registration date", "Mon, January 15, 2024 at 09:30:00", []}
  @now ~U[2026-06-19 12:00:00Z]
  @firefox_user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/43.4"
  @current_session_text gettext("Current session")
  @never_used_session_text gettext("Never")
  @unknown_user_agent_text gettext("Unknown")

  setup :verify_on_exit!

  describe "as a root user" do
    setup do
      stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
      :ok
    end

    test "render the profile page over a static (disconnected) request", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account} =
        register_and_log_in_root(%{conn: conn},
          user_account: [username: "alice", switch_edu_id: nil, created_at: @registered_at],
          session: [
            created_at: DateTime.add(@now, -10, :day),
            client_ip_address: "1.2.3.4",
            client_user_agent: @firefox_user_agent
          ]
        )

      expect_profile_page_calls(auth, mounts: 1, user_account: user_account, sessions: [session])

      html =
        conn
        |> get(@path)
        |> html_response(200)

      assert_html_title(html, "Profile · ArchiDep")

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               @registration_row
             ]

      assert current_sessions_table(html) == [
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"},
                "1.2.3.4", "Firefox on Mac", :none}
             ]
    end
  end

  describe "current sessions table" do
    setup do
      stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
      :ok
    end

    test "render every session state", %{conn: conn} do
      user_account = AccountsFactory.build(:user_account, root: true, active: true)

      recent_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -2, :day),
          used_at: DateTime.add(@now, -1, :day),
          client_ip_address: "1.2.3.4",
          client_user_agent: @firefox_user_agent
        )

      never_used_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -7, :day),
          used_at: nil,
          client_ip_address: nil,
          client_user_agent: "--- foobar ---"
        )

      current_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -10, :day),
          used_at: @now,
          client_ip_address: nil,
          client_user_agent: @firefox_user_agent
        )

      expiring_soon_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -29, :day),
          used_at: DateTime.add(@now, -3, :day),
          client_ip_address: "5.6.7.8",
          client_user_agent: @firefox_user_agent
        )

      expired_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -61, :day),
          used_at: DateTime.add(@now, -42, :day),
          client_ip_address: nil,
          client_user_agent: nil
        )

      sessions = [
        recent_session,
        never_used_session,
        current_session,
        expiring_soon_session,
        expired_session
      ]

      %{conn: conn, auth: auth} = conn_with_auth(conn, session: current_session)

      expect_profile_page_calls(auth, user_account: user_account, sessions: sessions)

      {:ok, _view, html} = live(conn, @path)

      assert current_sessions_table(html) == [
               {"Wed, June 17, 2026 at 12:00:00", "1 day ago", {:ok, "28 days"}, "1.2.3.4",
                "Firefox on Mac", :delete},
               {"Fri, June 12, 2026 at 12:00:00", @never_used_session_text, {:ok, "23 days"}, "-",
                @unknown_user_agent_text, :delete},
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"}, "-",
                "Firefox on Mac", :none},
               {"Thu, May 21, 2026 at 12:00:00", "3 days ago", {:soon, "1 day"}, "5.6.7.8",
                "Firefox on Mac", :delete},
               {"Sun, April 19, 2026 at 12:00:00", "42 days ago", :expired, "-", "-", :delete}
             ]
    end

    test "delete a session", %{conn: conn} do
      user_account = AccountsFactory.build(:user_account, root: true, active: true)

      current_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -10, :day),
          used_at: @now,
          client_ip_address: "1.2.3.4",
          client_user_agent: @firefox_user_agent
        )

      other_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -20, :day),
          used_at: DateTime.add(@now, -8, :day),
          client_ip_address: "5.6.7.8",
          client_user_agent: @firefox_user_agent
        )

      %{conn: conn, auth: auth} = conn_with_auth(conn, session: current_session)

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [current_session, other_session]
      )

      {:ok, view, html} = live(conn, @path)

      assert current_sessions_table(html) == [
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"},
                "1.2.3.4", "Firefox on Mac", :none},
               {"Sat, May 30, 2026 at 12:00:00", "8 days ago", {:ok, "10 days"}, "5.6.7.8",
                "Firefox on Mac", :delete}
             ]

      id = other_session.id
      expect(Accounts.ContextMock, :delete_session, fn ^auth, ^id -> {:ok, other_session} end)

      assert view
             |> element("tr:nth-child(2) button.delete-session")
             |> render_click()
             |> current_sessions_table() == [
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"},
                "1.2.3.4", "Firefox on Mac", :none}
             ]

      deleted = gettext("Deleted session")

      assert_flash_notification(view, :success, deleted)
    end

    test "show a notification when deleting a session that no longer exists", %{conn: conn} do
      user_account = AccountsFactory.build(:user_account, root: true, active: true)

      current_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -10, :day),
          used_at: @now,
          client_ip_address: "1.2.3.4",
          client_user_agent: @firefox_user_agent
        )

      other_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -20, :day),
          used_at: DateTime.add(@now, -8, :day),
          client_ip_address: "5.6.7.8",
          client_user_agent: @firefox_user_agent
        )

      %{conn: conn, auth: auth} = conn_with_auth(conn, session: current_session)

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [current_session, other_session]
      )

      {:ok, view, _html} = live(conn, @path)

      id = other_session.id

      expect(Accounts.ContextMock, :delete_session, fn ^auth, ^id ->
        {:error, :session_not_found}
      end)

      assert view
             |> element("tr:nth-child(2) button.delete-session")
             |> render_click()
             |> current_sessions_table() == [
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"},
                "1.2.3.4", "Firefox on Mac", :none}
             ]

      gone = gettext("Session no longer exists")

      assert_flash_notification(view, :warning, gone)
    end

    test "render the sessions table for a student", %{conn: conn} do
      user_account = AccountsFactory.build(:user_account, root: false, active: true)
      student = CourseFactory.build(:student, user: CourseFactory.build(:user))

      current_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: DateTime.add(@now, -10, :day),
          used_at: @now,
          client_ip_address: "1.2.3.4",
          client_user_agent: @firefox_user_agent
        )

      %{conn: conn, auth: auth} = conn_with_auth(conn, session: current_session)

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [current_session],
        student: student
      )

      {:ok, _view, html} = live(conn, @path)

      assert current_sessions_table(html) == [
               {"Tue, June 09, 2026 at 12:00:00", @current_session_text, {:ok, "20 days"},
                "1.2.3.4", "Firefox on Mac", :none}
             ]
    end
  end

  describe "changing the username as a student" do
    setup :register_and_log_in_student

    test "the change-username dialog is not rendered until the username is confirmed", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      student = %{student | username_confirmed: false}

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, view, _html} = live(conn, @path)

      refute has_element?(view, "##{@change_username_dialog_id}")
    end

    test "validate the new username", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      student = %{student | username_confirmed: true, username: "current-name"}
      id = student.id

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      expect(Course.ContextMock, :validate_student_config, fn ^auth,
                                                              ^id,
                                                              %{username: "bad name"} ->
        {:ok,
         student
         |> cast_username("bad name")
         |> Changeset.add_error(:username, "is invalid")}
      end)

      expect(Course.ContextMock, :validate_student_config, fn ^auth,
                                                              ^id,
                                                              %{username: "good-name"} ->
        {:ok, cast_username(student, "good-name")}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "##{@change_username_dialog_id}")

      assert view
             |> form("##{@change_username_dialog_id} form[phx-submit=\"configure\"]",
               student_config: %{username: "bad name"}
             )
             |> render_change()
             |> change_username_errors() == ["is invalid"]

      assert view
             |> form("##{@change_username_dialog_id} form[phx-submit=\"configure\"]",
               student_config: %{username: "good-name"}
             )
             |> render_change()
             |> change_username_errors() == []
    end

    test "change the username", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      student = %{student | username_confirmed: true, username: "current-name"}
      id = student.id
      configured_student = %{student | username: "new-name", version: student.version + 1}

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      expect(Course.ContextMock, :configure_student, fn ^auth, ^id, %{username: "new-name"} ->
        {:ok, configured_student}
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("##{@change_username_dialog_id} form[phx-submit=\"configure\"]",
               student_config: %{username: "new-name"}
             )
             |> render_submit()
             |> change_username_errors() == []

      assert_push_event(view, "execute-action", %{
        to: "##{@change_username_dialog_id}",
        action: "close"
      })

      notification = gettext("Username changed to {name}", name: "new-name")

      assert_flash_notification(view, :success, notification)

      # `configure_student/3` broadcasts a `StudentConfigured` event; the page's
      # `refresh_student` picks it up and the dialog form reflects the new
      # username on the next render.
      :ok =
        Course.PubSub.publish_student_updated(
          configured_student,
          StudentConfigured.new(configured_student),
          EventsFactory.build(:event_reference, version: configured_student.version)
        )

      wait_for_socket_assigns!(view, &(&1.student.username == "new-name"), "username changed")

      assert has_element?(view, ~s(##{@change_username_dialog_id} input[value="new-name"]))
    end

    test "show an error when the new username cannot be changed", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      student = %{student | username_confirmed: true, username: "current-name"}
      id = student.id

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      expect(Course.ContextMock, :configure_student, fn ^auth, ^id, %{username: "taken"} ->
        student
        |> cast_username("taken")
        |> Changeset.add_error(:username, "has already been taken")
        |> Changeset.apply_action(:update)
      end)

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> form("##{@change_username_dialog_id} form[phx-submit=\"configure\"]",
               student_config: %{username: "taken"}
             )
             |> render_submit()
             |> change_username_errors() == ["has already been taken"]

      refute_push_event(view, "execute-action", %{action: "close"})
    end

    test "closing the dialog backdrop changes nothing", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      student = %{student | username_confirmed: true, username: "current-name"}

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, view, _html} = live(conn, @path)

      assert view
             |> element(~s(##{@change_username_dialog_id} form.modal-backdrop))
             |> render_click()
             |> change_username_errors() == []

      assert has_element?(view, ~s(##{@change_username_dialog_id} input[value="current-name"]))
      refute_push_event(view, "execute-action", %{})
      assert flash_notifications(view) == []
    end
  end

  describe "profile data display" do
    test "render the data display for a root user with a Switch edu-ID", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account} =
        register_and_log_in_root(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: "Jane",
                last_name: "Doe",
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ]
        )

      expect_profile_page_calls(auth, user_account: user_account, sessions: [session])

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Switch edu-ID name", "Jane Doe", []},
               {"Swiss edu person unique ID", "swiss-id-123", []},
               @registration_row
             ]
    end

    test "render the data display for a root user without a Switch edu-ID", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account} =
        register_and_log_in_root(%{conn: conn},
          user_account: [username: "alice", switch_edu_id: nil, created_at: @registered_at]
        )

      expect_profile_page_calls(auth, user_account: user_account, sessions: [session])

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               @registration_row
             ]
    end

    test "render the data display for a root user whose Switch edu-ID has no name", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account} =
        register_and_log_in_root(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: nil,
                last_name: nil,
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ]
        )

      expect_profile_page_calls(auth, user_account: user_account, sessions: [session])

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Swiss edu person unique ID", "swiss-id-123", []},
               @registration_row
             ]
    end

    test "render the data display for a student with a confirmed username", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account, student: student} =
        register_and_log_in_student(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: "Jane",
                last_name: "Doe",
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ],
          student: [
            username: "current-name",
            username_confirmed: true,
            email: "student@example.com"
          ]
        )

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               {"Username", "current-name", ["Change"]},
               @registration_row
             ]
    end

    test "render the data display for a student with an unconfirmed username", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account, student: student} =
        register_and_log_in_student(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: "Jane",
                last_name: "Doe",
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ],
          student: [
            username: "current-name",
            username_confirmed: false,
            email: "student@example.com"
          ]
        )

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               @registration_row
             ]
    end

    test "hide the account username row when the account has no username", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account} =
        register_and_log_in_root(%{conn: conn},
          user_account: [username: nil, switch_edu_id: nil, created_at: @registered_at]
        )

      expect_profile_page_calls(auth, user_account: user_account, sessions: [session])

      {:ok, _view, html} = live(conn, @path)

      assert data_display_rows(html) == [@registration_row]
    end
  end

  describe "profile student updates" do
    test "re-render the data display when the student is updated", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account, student: student} =
        register_and_log_in_student(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: "Jane",
                last_name: "Doe",
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ],
          student: [
            username: "current-name",
            username_confirmed: true,
            email: "student@example.com",
            user: CourseFactory.build(:user)
          ]
        )

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               {"Username", "current-name", ["Change"]},
               @registration_row
             ]

      updated = %{student | username: "renamed", version: student.version + 1}

      :ok =
        Course.PubSub.publish_student_updated(
          updated,
          StudentUpdated.new(updated),
          EventsFactory.build(:event_reference, version: updated.version)
        )

      wait_for_socket_assigns!(view, &(&1.student.username == "renamed"), "student renamed")

      assert view |> render() |> data_display_rows() == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               {"Username", "renamed", ["Change"]},
               @registration_row
             ]
    end

    test "reveal the username row when the student confirms their username", %{conn: conn} do
      %{conn: conn, auth: auth, session: session, user_account: user_account, student: student} =
        register_and_log_in_student(%{conn: conn},
          user_account: [
            username: "alice",
            switch_edu_id:
              AccountsFactory.build(:switch_edu_id,
                first_name: "Jane",
                last_name: "Doe",
                swiss_edu_person_unique_id: "swiss-id-123"
              ),
            created_at: @registered_at
          ],
          student: [
            username: "current-name",
            username_confirmed: false,
            email: "student@example.com",
            user: CourseFactory.build(:user)
          ]
        )

      expect_profile_page_calls(auth,
        user_account: user_account,
        sessions: [session],
        student: student
      )

      {:ok, view, html} = live(conn, @path)

      assert data_display_rows(html) == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               @registration_row
             ]

      updated = %{student | username_confirmed: true, version: student.version + 1}

      :ok =
        Course.PubSub.publish_student_updated(
          updated,
          StudentConfigured.new(updated),
          EventsFactory.build(:event_reference, version: updated.version)
        )

      wait_for_socket_assigns!(view, & &1.student.username_confirmed, "username confirmed")

      assert view |> render() |> data_display_rows() == [
               {"Account username", "alice", []},
               {"Email", "student@example.com", []},
               {"Switch edu-ID name", "Jane Doe", []},
               {"Username", "current-name", ["Change"]},
               @registration_row
             ]
    end
  end

  test "accessing the profile page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  # Sets up the context mocks the profile page reads on mount. The page fetches
  # the authenticated account and its active sessions on every mount, and a
  # LiveView mounts twice — the disconnected HTTP render, then the connected
  # socket — so each read is expected twice (pass `mounts: 1` for a static
  # `get/2` request, which mounts once). When a `:student` is given, the
  # authenticated student is fetched both by the `LiveAuth` on-mount hook and by
  # the LiveView itself, hence twice per mount.
  defp expect_profile_page_calls(auth, opts) do
    mounts = Keyword.get(opts, :mounts, 2)
    user_account = Keyword.fetch!(opts, :user_account)
    sessions = Keyword.fetch!(opts, :sessions)

    expect(Accounts.ContextMock, :user_account, mounts, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, mounts, fn ^auth -> sessions end)

    case Keyword.fetch(opts, :student) do
      {:ok, student} ->
        expect(Course.ContextMock, :fetch_authenticated_student, 2 * mounts, fn ^auth ->
          {:ok, StudentView.from(student)}
        end)

        # The live view keeps the student read-model current through the Course
        # boundary; route those calls to the real read-model plumbing so a real
        # broadcast still drives the re-render.
        stub(Course.ContextMock, :subscribe_student, &ReadStudents.subscribe_student/1)
        stub(Course.ContextMock, :refresh_student, &ReadStudents.refresh_student/2)

      :error ->
        :ok
    end

    :ok
  end

  defp current_sessions_table(html) do
    html
    |> find_html_elements("##{@current_sessions_table_id} tbody tr")
    |> Enum.map(fn row ->
      [login, last_used, expiration, ip, client, _actions] = find_html_elements(row, "td")
      action = if find_html_elements(row, "button.delete-session") != [], do: :delete, else: :none

      {html_element_text(login), html_element_text(last_used), expiration_state(expiration),
       html_element_text(ip), html_element_text(client), action}
    end)
  end

  # Projects the expiration cell to its semantic state: the badge colour encodes
  # whether the session is expired, expiring soon, or fine.
  defp expiration_state(td) do
    cond do
      find_html_elements(td, ".badge-error") != [] -> :expired
      find_html_elements(td, ".badge-warning") != [] -> {:soon, html_element_text(td)}
      find_html_elements(td, ".badge-success") != [] -> {:ok, html_element_text(td)}
    end
  end

  defp data_display_rows(html) do
    html
    |> find_html_elements("dl > div")
    |> Enum.map(fn row ->
      [title] = row |> find_html_elements("dt") |> Enum.map(&html_element_text/1)
      [dd] = find_html_elements(row, "dd")
      controls = dd |> find_html_elements("button") |> Enum.map(&html_element_text/1)

      # Strip control labels from the cell text so the data value and the
      # interactive affordances are projected as distinct fields.
      value =
        controls
        |> Enum.reduce(html_element_text(dd), &String.replace(&2, &1, ""))
        |> String.trim()

      {title, value, controls}
    end)
  end

  defp change_username_errors(html),
    do:
      html
      |> find_html_elements("##{@change_username_dialog_id} p.text-error")
      |> Enum.map(&html_element_text/1)

  defp cast_username(student, username),
    do: Changeset.cast(student, %{username: username}, [:username])
end
