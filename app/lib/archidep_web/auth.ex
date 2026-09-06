defmodule ArchiDepWeb.Auth do
  @moduledoc """
  Helpers to handle HTTP authentication based on session cookies.
  """

  import ArchiDepWeb.Helpers.ConnHelpers
  import ArchiDepWeb.Helpers.SocketHelpers
  import Phoenix.Controller
  import Plug.Conn
  alias ArchiDep.Accounts
  alias ArchiDep.Authentication
  alias ArchiDep.Clock
  alias ArchiDepWeb.Endpoint
  alias Plug.Conn

  @remember_me_cookie "_archidep_remember_me"

  # Carries the session token for as long as the cookie lasts, so it is stated
  # to be off plain HTTP for the same reason the session cookie it stands in for
  # is (see `ArchiDepWeb.Endpoint`).
  #
  # How long that is is deliberately absent here: a cookie outliving the session
  # it carries is a cookie the browser goes on sending after the server has
  # stopped accepting it, so the lifetime is derived per login from that
  # session's own expiry rather than restated as a second number to keep in step
  # with it.
  @remember_me_options [sign: true, same_site: "Lax", secure: true]

  @doc """
  Logs the user_account in.

  It renews the session ID and clears the whole session to avoid fixation
  attacks. See the renew_session function to customize this behaviour.
  """
  @spec log_in(Conn.t(), Authentication.t()) :: Conn.t()
  def log_in(conn, auth) do
    token = Authentication.session_token(auth)
    user_return_to = get_session(conn, :user_return_to)
    remember_me = get_session(conn, :remember_me, false)

    conn
    |> renew_session()
    |> put_session(:session_token, token)
    |> put_session(:live_socket_id, live_socket_id(auth))
    |> delete_session(:user_return_to)
    |> maybe_write_remember_me_cookie(auth, token, remember_me)
    |> redirect(to: user_return_to || signed_in_path())
  end

  @doc """
  Logs out the user account.

  It clears all session data for safety.
  """
  @spec log_out(Conn.t()) :: Conn.t()
  def log_out(conn) do
    if auth = conn.assigns[:auth] do
      :ok = Accounts.log_out(auth)
      disconnect_session(auth)
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/login")
  end

  @spec disconnect_session(Authentication.t()) :: :ok
  def disconnect_session(auth) do
    :ok = Endpoint.broadcast(live_socket_id(auth), "disconnect", %{})
  end

  defp maybe_write_remember_me_cookie(conn, auth, token, true),
    do:
      put_resp_cookie(
        conn,
        @remember_me_cookie,
        token,
        Keyword.put(@remember_me_options, :max_age, remember_me_max_age(auth))
      )

  defp maybe_write_remember_me_cookie(conn, _auth, _token, false), do: conn

  # As long as the session has left, so the browser stops offering the token at
  # the moment the session it names stops being accepted.
  defp remember_me_max_age(auth),
    do: DateTime.diff(Authentication.session_expires_at(auth), Clock.now())

  # This function renews the session ID and erases the whole session to avoid
  # fixation attacks. If there is any data in the session you may want to
  # preserve after log in/log out, you must explicitly fetch the session data
  # before clearing and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Authenticates the user by looking into the session and session cookie.
  """
  @spec fetch_authentication(Conn.t(), keyword) :: Conn.t()
  def fetch_authentication(conn, _opts) do
    conn
    |> get_token_from_session_or_remember_me_cookie()
    |> authenticate_with_token()
  end

  @doc """
  Used for routes that are only accessible when the user is not authenticated,
  such as the login page.
  """
  @spec redirect_if_user_is_authenticated(Conn.t(), keyword) :: Conn.t()
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:auth] do
      conn
      |> redirect(to: signed_in_path())
      |> halt()
    else
      conn
    end
  end

  defp get_token_from_session_or_remember_me_cookie(conn) do
    if session_token = get_session(conn, :session_token) do
      assign(conn, :session_token, session_token)
    else
      conn_with_cookies = fetch_cookies(conn, signed: [@remember_me_cookie])

      if session_token = conn_with_cookies.cookies[@remember_me_cookie] do
        conn_with_cookies
        |> put_session(:session_token, session_token)
        |> assign(:session_token, session_token)
      else
        conn_with_cookies
      end
    end
  end

  defp authenticate_with_token(%Conn{assigns: %{session_token: token}} = conn)
       when is_binary(token) do
    case Accounts.validate_session_token(token, conn_metadata(conn)) do
      {:ok, auth} -> assign(conn, :auth, auth)
      {:error, :session_not_found} -> assign(conn, :auth, nil)
    end
  end

  defp authenticate_with_token(conn) do
    assign(conn, :auth, nil)
  end

  defp signed_in_path, do: "/app"
end
