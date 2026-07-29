defmodule ArchiDepWeb.Support.LiveCase do
  @moduledoc """
  Test case template for testing live views and components.
  """

  use ExUnit.CaseTemplate

  import ArchiDep.Support.ProcessTestHelpers
  import ArchiDepWeb.Support.ConnCase
  import Hammox
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias ArchiDep.Accounts
  alias ArchiDep.Clock.SystemClock
  alias ArchiDepWeb.Endpoint
  alias Phoenix.LiveViewTest.View
  alias Plug.Conn

  @endpoint Endpoint

  using do
    quote do
      # Import conveniences for testing with connections
      use Gettext, backend: ArchiDepWeb.Gettext
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDep.Support.DateTestHelpers
      import ArchiDep.Support.ProcessTestHelpers
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
    # Default the injectable clock to the real system clock; a test that needs
    # deterministic time-dependent rendering overrides this with a fixed
    # instant.
    Hammox.stub(ArchiDep.Clock.Mock, :now, &SystemClock.now/0)

    # Scope global PubSub topics to this test with a unique suffix so concurrent
    # async tests never observe each other's broadcasts on shared topics (see
    # `docs/testing.md`).
    topic_suffix = ":test-#{System.unique_integer([:positive])}"
    Hammox.stub(ArchiDep.PubSub.Scope.Mock, :suffix, fn -> topic_suffix end)

    # Every page of the dashboard renders the course material's navigation,
    # which is coloured by how far the course has got. A test that cares about
    # those colours overrides this with sessions of its own.
    Hammox.stub(ArchiDep.Course.ContextMock, :course_sessions, fn -> [] end)

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

    stub(Accounts.ContextMock, :validate_session_token, fn "foo", _metadata ->
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
    expected_redirect = "/login?#{URI.encode_query(to: path)}"
    {:error, {:redirect, %{flash: flash, to: ^expected_redirect}}} = live(conn, path)
    assert [%{message: "You must log in to access this page.", type: :error}] = Map.values(flash)

    conn
  end

  @doc """
  Wait for a view socket's assigns to match a custom condition.
  """
  @spec wait_for_socket_assigns!(struct(), (term -> boolean()), String.t()) :: :ok
  def wait_for_socket_assigns!(view, fun, description)
      when is_struct(view, View) and is_function(fun, 1),
      do:
        wait_for_state!(
          view.pid,
          fn state -> fun.(state.socket.assigns) end,
          "socket assigns never matched #{description}"
        )

  @doc """
  Returns the notifications currently in the live view's flash, projected to
  `{type, message}` tuples ordered by flash key.

  A flash notification is a `Flashy.Normal` struct whose `component` field holds
  a render function, so it cannot be asserted by whole-value equality; its
  `{type, message}` is the meaningful projection (mirroring the DOM-projection
  discipline of the web layer).

  Notifications sent to the socket are delivered asynchronously, so wait for one
  to arrive with `wait_for_socket_assigns!/3` and `has_flash_notification?/2`,
  then assert the full projection by equality:

      wait_for_socket_assigns!(view, &has_flash_notification?(&1, :success), "deleted")
      assert flash_notifications(view) == [{:success, "Deleted session"}]

  Accepts either a `Phoenix.LiveViewTest.View` or a map of socket assigns (the
  latter for use inside a `wait_for_socket_assigns!/3` predicate).
  """
  @spec flash_notifications(struct() | map()) :: [{atom(), String.t()}]
  def flash_notifications(view) when is_struct(view, View),
    do: flash_notifications(:sys.get_state(view.pid).socket.assigns)

  def flash_notifications(assigns) when is_map(assigns),
    do:
      assigns.flash
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {_key, notification} -> {notification.type, notification.message} end)

  @doc """
  Indicates whether the live view's flash currently holds a notification of the
  given type (`:success`, `:warning`, `:error`).

  Intended as a loose wait condition for `wait_for_socket_assigns!/3` — wait for
  the notification to arrive, then assert its exact `{type, message}` projection
  with `flash_notifications/1`.

  Accepts either a `Phoenix.LiveViewTest.View` or a map of socket assigns.
  """
  @spec has_flash_notification?(struct() | map(), atom()) :: boolean()
  def has_flash_notification?(view_or_assigns, type) when is_atom(type),
    do:
      Enum.any?(flash_notifications(view_or_assigns), fn {notification_type, _message} ->
        notification_type == type
      end)

  @doc """
  Waits for a flash notification of `type` to arrive, then asserts the live
  view's flash holds exactly that one `{type, message}` notification.

  A convenience for the common single-notification case: it combines the
  asynchronous wait (`wait_for_socket_assigns!/3` + `has_flash_notification?/2`)
  with the exact projection assertion (`flash_notifications/1`). When more than
  one notification is expected, assert `flash_notifications/1` directly.
  """
  @spec assert_flash_notification(struct(), atom(), String.t()) :: :ok
  def assert_flash_notification(view, type, message)
      when is_struct(view, View) and is_atom(type) do
    wait_for_socket_assigns!(
      view,
      &has_flash_notification?(&1, type),
      "#{type} flash notification"
    )

    assert flash_notifications(view) == [{type, message}]
    :ok
  end
end
