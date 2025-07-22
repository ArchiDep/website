defmodule ArchiDepWeb.Support.LiveCase do
  use ExUnit.CaseTemplate

  import Hammox
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias ArchiDep.Accounts
  alias ArchiDepWeb.Endpoint
  alias Plug.Conn
  alias Plug.Crypto

  @endpoint Endpoint
  @remember_me_cookie "_archidep_remember_me"

  using do
    quote do
      # Import conveniences for testing with connections
      use Gettext, backend: ArchiDepWeb.Gettext
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Support.DateTestHelpers
      import ArchiDepWeb.Support.ConnCase
      import ArchiDepWeb.Support.HtmlTestHelpers
      import ArchiDepWeb.Support.LiveCase
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      alias ArchiDepWeb.Endpoint
      alias Ecto.UUID

      @endpoint ArchiDepWeb.Endpoint
      @pubsub ArchiDep.PubSub
    end
  end

  setup do
    {:ok, conn: build_conn(), start: DateTime.utc_now()}
  end

  setup :verify_on_exit!

  @doc """
  Ensures that the specified operation redirects a non-authenticated user to the
  login page. The following situations are checked:

  * The user does not authenticate.
  * The user has an invalid token in the session.
  * The user has an invalid token in the remember me cookie.
  """
  @spec assert_live_anonymous_user_redirected_to_login(Conn.t(), String.t()) :: :ok
  def assert_live_anonymous_user_redirected_to_login(conn, path) do
    assert_live_redirected_to_login(conn, path)

    stub(Accounts.ContextMock, :validate_session, fn "foo", _metadata ->
      {:error, :session_not_found}
    end)

    conn
    |> put_user_token_in_session("foo")
    |> assert_live_redirected_to_login(path)

    conn
    |> put_user_token_in_remember_me_cookie("foo")
    |> assert_live_redirected_to_login(path)

    :ok
  end

  @doc """
  Asserts that attempting to open the specified live view will cause the user to
  be redirected to the login page.
  """
  @spec assert_live_redirected_to_login(Conn.t(), String.t()) :: Conn.t()
  def assert_live_redirected_to_login(conn, path) do
    {:error, {:redirect, %{flash: flash, to: "/login"}}} = live(conn, path)
    assert [%{message: "You must log in to access this page.", type: :error}] = Map.values(flash)

    conn
  end

  defp put_user_token_in_session(conn, token) when is_binary(token),
    do: init_test_session(conn, %{session_token: token})

  defp put_user_token_in_remember_me_cookie(conn, token) when is_binary(token) do
    put_req_cookie(
      conn,
      @remember_me_cookie,
      Crypto.sign(secret_key_base(), @remember_me_cookie <> "_cookie", token,
        keys: Plug.Keys,
        max_age: 60
      )
    )
  end

  @doc """
  Returns the application's configured secret key base.
  """
  @spec secret_key_base() :: String.t()
  def secret_key_base,
    do: :archidep |> Application.fetch_env!(Endpoint) |> Keyword.fetch!(:secret_key_base)
end
