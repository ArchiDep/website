defmodule ArchiDepWeb.Profile.ProfileLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.Support.AccountsFactory

  @path "/profile"
  @current_sessions_table_id "current-sessions"
  @no_actions ""
  @current_session_text gettext("Current session")
  @expired_session_text gettext("Expired")
  @delete_session_text gettext("Delete")
  @never_used_session_text gettext("Never")
  @unknown_user_agent_text gettext("Unknown")

  setup :verify_on_exit!

  test "show the profile page", %{conn: conn!} do
    %{conn: conn!, auth: auth, session: session, user_account: user_account} =
      conn_with_auth(conn!)

    expect(Accounts.ContextMock, :user_account, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, fn ^auth -> [session] end)

    conn!
    |> get(@path)
    |> html_response(200)
    |> assert_html_title("Profile · ArchiDep")
  end

  test "connect to the profile page", %{conn: conn!} do
    %{conn: conn!, auth: auth, session: session, user_account: user_account} =
      conn_with_auth(conn!)

    expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)

    {:ok, _view, html} = live(conn!, @path)

    html
    |> assert_html_title("Profile · ArchiDep")
    |> with_current_sessions_table_rows(fn rows ->
      assert [
               [_login, @current_session_text, _exp, _ip, _client, @no_actions]
             ] = rows
    end)
  end

  test "all sessions are shown in the current sessions table of the profile page", %{conn: conn!} do
    user_account = AccountsFactory.build(:user_account, active: true)

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

  test "delete a session in the profile page", %{conn: conn!} do
    user_account = AccountsFactory.build(:user_account)
    current_session = AccountsFactory.build(:current_session, user_account: user_account)

    other_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(20),
        used_at: days_ago(8)
      )

    sessions = [
      current_session,
      other_session
    ]

    %{conn: conn!, auth: auth} = conn_with_auth(conn!, session: current_session)

    expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)

    {:ok, view, html} = live(conn!, @path)

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

  test "a notification is shown in the profile page when deleting a session that no longer exists",
       %{conn: conn!} do
    user_account = AccountsFactory.build(:user_account)
    current_session = AccountsFactory.build(:current_session, user_account: user_account)

    other_session =
      AccountsFactory.build(:user_session,
        user_account: user_account,
        created_at: days_ago(20),
        used_at: days_ago(8)
      )

    sessions = [
      current_session,
      other_session
    ]

    %{auth: auth, conn: conn!} = conn_with_auth(conn!, session: current_session)

    expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> sessions end)

    {:ok, view, html} = live(conn!, @path)

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

  test "accessing the profile page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  defp with_current_sessions_table_rows(html, fun) do
    html
    |> find_html_elements("##{@current_sessions_table_id} tbody tr")
    |> Enum.map(fn {"tr", _attrs, children} ->
      children |> Floki.find("td") |> Enum.map(&html_text/1)
    end)
    |> fun.()

    html
  end

  defp html_text(element), do: [element] |> Floki.text() |> String.trim()
end
