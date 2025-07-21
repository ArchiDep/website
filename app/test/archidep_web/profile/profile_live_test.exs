defmodule ArchiDepWeb.Profile.ProfileLiveTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  import Phoenix.LiveViewTest
  alias ArchiDep.Accounts

  @endpoint ArchiDepWeb.Endpoint

  setup :verify_on_exit!

  test "disconnected and connected mount", %{conn: conn!} do
    %{conn: conn!, auth: auth, session: session, user_account: user_account} =
      conn_with_auth(conn!)

    expect(Accounts.ContextMock, :user_account, 2, fn ^auth -> user_account end)
    expect(Accounts.ContextMock, :fetch_active_sessions, 2, fn ^auth -> [session] end)

    conn! = get(conn!, "/profile")
    assert html_response(conn!, 200) =~ "Profile"
    {:ok, _view, _html} = live(conn!)
  end
end
