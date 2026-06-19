defmodule ArchiDepWeb.Profile.ProfileLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Support.AccountsFactory
  alias Ecto.Changeset

  @path "/profile"
  @current_sessions_table_id "current-sessions"
  @change_username_dialog_id "change-username-dialog"
  @no_actions ""
  @current_session_text gettext("Current session")
  @expired_session_text gettext("Expired")
  @delete_session_text gettext("Delete")
  @never_used_session_text gettext("Never")
  @unknown_user_agent_text gettext("Unknown")

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    test "show the profile page", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account
    } do
      expect(Accounts.ContextMock, :user_account, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, fn ^auth -> [session] end)

      conn
      |> get(@path)
      |> html_response(200)
      |> assert_html_title("Profile · ArchiDep")
    end

    test "render the current sessions table", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account
    } do
      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)

      {:ok, _view, html} = live(conn, @path)

      html
      |> assert_html_title("Profile · ArchiDep")
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login, @current_session_text, _exp, _ip, _client, @no_actions]
               ] = rows
      end)
    end

    test "delete a session", %{
      conn: conn,
      auth: auth,
      session: current_session,
      user_account: user_account
    } do
      other_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: days_ago(20),
          used_at: days_ago(8)
        )

      sessions = [current_session, other_session]

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)

      {:ok, view, html} = live(conn, @path)

      html
      |> assert_html_title("Profile · ArchiDep")
      |> with_current_sessions_table_rows(fn rows ->
        eight_days_ago = gettext("{time} ago", time: "8 days")

        assert [
                 [_login1, @current_session_text, _exp1, _ip1, _client1, @no_actions],
                 [_login2, ^eight_days_ago, _exp2, _ip2, _client2, @delete_session_text]
               ] = rows
      end)

      id = other_session.id
      expect(Accounts.ContextMock, :delete_session, fn ^auth, ^id -> {:ok, other_session} end)

      view
      |> element("tr:nth-child(2) button.delete-session")
      |> render_click()
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login, @current_session_text, _exp, _ip, _client, @no_actions]
               ] = rows
      end)
    end

    test "show a notification when deleting a session that no longer exists", %{
      conn: conn,
      auth: auth,
      session: current_session,
      user_account: user_account
    } do
      other_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: days_ago(20),
          used_at: days_ago(8)
        )

      sessions = [current_session, other_session]

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)

      {:ok, view, html} = live(conn, @path)

      html
      |> assert_html_title("Profile · ArchiDep")
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login1, @current_session_text, _exp1, _ip1, _client1, @no_actions],
                 [_login2, _last_used2, _exp2, _ip2, _client2, @delete_session_text]
               ] = rows
      end)

      id = other_session.id

      expect(Accounts.ContextMock, :delete_session, fn ^auth, ^id ->
        {:error, :session_not_found}
      end)

      view
      |> element("tr:nth-child(2) button.delete-session")
      |> render_click()
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login, @current_session_text, _exp, _ip, _client, @no_actions]
               ] = rows
      end)

      wait_for_socket_assigns!(
        view,
        &match?(
          [%{message: "Session no longer exists", type: :warning}],
          Map.values(&1.flash)
        ),
        "session no longer exists notification"
      )
    end
  end

  describe "as a student" do
    setup :register_and_log_in_student

    test "render the current sessions table", %{
      conn: conn,
      auth: auth,
      session: session,
      user_account: user_account,
      student: student
    } do
      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

      {:ok, _view, html} = live(conn, @path)

      html
      |> assert_html_title("Profile · ArchiDep")
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login, @current_session_text, _exp, _ip, _client, @no_actions]
               ] = rows
      end)
    end

    test "delete a session", %{
      conn: conn,
      auth: auth,
      session: current_session,
      user_account: user_account,
      student: student
    } do
      other_session =
        AccountsFactory.build(:user_session,
          user_account: user_account,
          created_at: days_ago(20),
          used_at: days_ago(8)
        )

      sessions = [current_session, other_session]

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

      {:ok, view, html} = live(conn, @path)

      html
      |> assert_html_title("Profile · ArchiDep")
      |> with_current_sessions_table_rows(fn rows ->
        eight_days_ago = gettext("{time} ago", time: "8 days")

        assert [
                 [_login1, @current_session_text, _exp1, _ip1, _client1, @no_actions],
                 [_login2, ^eight_days_ago, _exp2, _ip2, _client2, @delete_session_text]
               ] = rows
      end)

      id = other_session.id
      expect(Accounts.ContextMock, :delete_session, fn ^auth, ^id -> {:ok, other_session} end)

      view
      |> element("tr:nth-child(2) button.delete-session")
      |> render_click()
      |> with_current_sessions_table_rows(fn rows ->
        assert [
                 [_login, @current_session_text, _exp, _ip, _client, @no_actions]
               ] = rows
      end)
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

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

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

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

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
      configured_student = %{student | username: "new-name"}

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

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

      wait_for_socket_assigns!(
        view,
        &match?([%{message: ^notification, type: :success}], Map.values(&1.flash)),
        "username changed notification"
      )

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

      expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
      expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)
      expect(Course.ContextMock, :fetch_authenticated_student, 4, fn ^auth -> {:ok, student} end)

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
  end

  test "all sessions are shown in the current sessions table of the profile page", %{conn: conn!} do
    user_account = AccountsFactory.build(:user_account, root: true, active: true)

    most_recent_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(2),
        used_at: days_ago(1),
        client_ip_address: "1.2.3.4"
      )

    unused_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(7),
        used_at: nil,
        client_user_agent: "--- foobar ---"
      )

    current_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(10),
        used_at: utc_now(),
        client_user_agent:
          "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/43.4"
      )

    expired_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(61),
        used_at: days_ago(42),
        client_user_agent: nil
      )

    sessions = [
      most_recent_session,
      unused_session,
      current_session,
      expired_session
    ]

    %{conn: conn!, auth: auth} = conn_with_auth(conn!, session: current_session)

    expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)

    {:ok, _view, html} = live(conn!, @path)

    html
    |> assert_html_title("Profile · ArchiDep")
    |> with_current_sessions_table_rows(fn rows ->
      one_day_ago = gettext("{time} ago", time: "1 day")
      forty_two_days_ago = gettext("{time} ago", time: "42 days")

      assert [
               [_login, ^one_day_ago, _exp, "1.2.3.4", _client, @delete_session_text],
               [
                 _login1,
                 @never_used_session_text,
                 _exp1,
                 _ip1,
                 @unknown_user_agent_text,
                 @delete_session_text
               ],
               [_login2, @current_session_text, _exp2, _ip2, "Firefox on Mac", @no_actions],
               [
                 _login3,
                 ^forty_two_days_ago,
                 @expired_session_text,
                 _ip3,
                 "-",
                 @delete_session_text
               ]
             ] = rows
    end)
  end

  test "accessing the profile page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  defp with_current_sessions_table_rows(html, fun) do
    html
    |> find_html_elements("##{@current_sessions_table_id} tbody tr")
    |> Enum.map(fn row ->
      row |> find_html_elements("td") |> Enum.map(&html_element_text/1)
    end)
    |> fun.()

    html
  end

  defp change_username_errors(html),
    do:
      html
      |> find_html_elements("##{@change_username_dialog_id} p.text-error")
      |> Enum.map(&html_element_text/1)

  defp cast_username(student, username),
    do: Changeset.cast(student, %{username: username}, [:username])
end
