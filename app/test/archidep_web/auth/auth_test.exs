defmodule ArchiDepWeb.AuthTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  alias ArchiDep.Accounts
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Support.Factory

  @remember_me_cookie "_archidep_remember_me"
  @user_agent "ExUnit/1.0"
  @metadata ClientMetadata.new({127, 0, 0, 1}, @user_agent)

  setup :verify_on_exit!

  describe "fetch_authentication via the remember-me cookie" do
    test "authenticate a user from a valid remember-me cookie and copy the token into the session",
         %{conn: conn} do
      token = "remember-me-session-token"
      auth = Factory.build(:authentication)

      stub(Accounts.ContextMock, :validate_session_token, fn ^token, @metadata -> {:ok, auth} end)

      conn =
        conn
        |> put_user_token_in_remember_me_cookie(token)
        |> put_req_header("user-agent", @user_agent)
        |> get(~p"/login")

      # The cookie authenticated the request, so the anonymous-only login page
      # redirects to the application, the token is persisted into the session, and
      # the plug leaves the cookie itself untouched.
      assert redirected_to(conn) == ~p"/app"
      assert get_session(conn) == %{"session_token" => token}
      refute Map.has_key?(conn.resp_cookies, @remember_me_cookie)
    end
  end

  describe "set_current_path" do
    test "assign the current request path", %{conn: conn} do
      conn = get(conn, ~p"/login")

      assert conn.assigns.current_path == "/login"
    end
  end
end
