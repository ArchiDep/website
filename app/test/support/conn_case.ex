defmodule ArchiDepWeb.Support.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ArchiDepWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import Hammox
  import Phoenix.ConnTest
  import Plug.Conn
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Schemas.PreregisteredUser
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.DataCase
  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Endpoint
  alias Phoenix.ConnTest
  alias Plug.Conn
  alias Plug.Crypto

  @remember_me_cookie "_archidep_remember_me"

  @type conn_with_auth_session_option :: {:session, UserSession.t()}
  @type conn_with_auth_option :: conn_with_auth_session_option()

  @typedoc """
  The context added by the authentication setup helpers
  (`register_and_log_in_root/1` and friends): an authenticated connection along
  with the authentication, session and user account it was built from.
  """
  @type logged_in_context :: %{
          conn: Conn.t(),
          auth: Authentication.t(),
          session: UserSession.t(),
          user_account: UserAccount.t()
        }

  @typedoc """
  The `t:logged_in_context/0` returned by `register_and_log_in_student/1`,
  augmented with the student and preregistered user backing the logged-in
  account.
  """
  @type logged_in_student_context :: %{
          conn: Conn.t(),
          auth: Authentication.t(),
          session: UserSession.t(),
          user_account: UserAccount.t(),
          student: Student.t(),
          preregistered_user: PreregisteredUser.t()
        }

  using do
    quote do
      # The default endpoint for testing
      @endpoint ArchiDepWeb.Endpoint

      use ArchiDepWeb, :verified_routes

      # Import conveniences for testing with connections
      import ArchiDep.Helpers.PipeHelpers
      import ArchiDepWeb.Support.ConnCase
      import Phoenix.ConnTest
      import Plug.Conn
      alias Plug.Conn
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)

    # Every page rendered in the application shell shows the course material's
    # navigation, which is coloured by how far the course has got. A test that
    # cares about those colours overrides this with sessions of its own.
    stub(ArchiDep.Course.ContextMock, :course_sessions, fn -> [] end)

    {:ok, conn: ConnTest.build_conn()}
  end

  @spec conn_with_auth(Conn.t(), Keyword.t(conn_with_auth_option())) :: %{
          conn: Conn.t(),
          auth: Authentication.t(),
          session: UserSession.t(),
          user_account: UserAccount.t()
        }
  def conn_with_auth(conn, opts! \\ []) when is_struct(conn, Conn) and is_list(opts!) do
    {session, opts!} =
      Keyword.pop_lazy(opts!, :session, fn ->
        AccountsFactory.build(:user_session,
          created_at: DateTime.add(DateTime.utc_now(), -1, :hour),
          client_user_agent: Factory.user_agent(),
          impersonated_user_account: nil
        )
      end)

    [] = Keyword.keys(opts!)

    session_token = session.token

    auth =
      Factory.build(:authentication,
        principal_id: session.user_account_id,
        username: session.user_account.username,
        root: session.user_account.root,
        session_id: session.id,
        session_token: session_token,
        impersonated_id: session.impersonated_user_account_id
      )

    client_metadata = ClientMetadata.new({127, 0, 0, 1}, session.client_user_agent)

    stub(Accounts.ContextMock, :validate_session_token, fn ^session_token, ^client_metadata ->
      {:ok, auth}
    end)

    authenticated_conn =
      conn
      |> init_test_session(%{
        session_token: session_token,
        live_socket_id: live_socket_id(session)
      })
      |> put_req_header("user-agent", session.client_user_agent)
      |> put_private(__MODULE__, auth: auth, session: session, user_account: session.user_account)

    %{conn: authenticated_conn, auth: auth, session: session, user_account: session.user_account}
  end

  @doc """
  `ExUnit` setup helper that registers a root user account and authenticates the
  test connection as that user.

  Replaces `:conn` in the test context with an authenticated connection and adds
  `:auth`, `:session` and `:user_account`. Use it as
  `setup :register_and_log_in_root`.

  When called directly (rather than as a `setup` hook), `overrides` may carry
  `:user_account` and `:session` keyword lists that are merged into the
  respective factory builds — use this to pin specific displayed values (a
  username, a registration date, an IP address) instead of hand-rolling the
  whole authenticated graph.
  """
  @spec register_and_log_in_root(%{:conn => Conn.t(), optional(atom()) => term()}, keyword()) ::
          logged_in_context()
  def register_and_log_in_root(context, overrides \\ [])

  def register_and_log_in_root(%{conn: conn}, overrides) when is_list(overrides) do
    {user_account_overrides, session_overrides} = split_login_overrides(overrides)

    [root: true, active: true]
    |> Keyword.merge(user_account_overrides)
    |> then(&AccountsFactory.build(:user_account, &1))
    |> log_in_user_account(conn, session_overrides)
  end

  @doc """
  `ExUnit` setup helper that registers a student (a non-root user account linked
  to a preregistered user) and authenticates the test connection as that user.

  Replaces `:conn` in the test context with an authenticated connection and adds
  `:auth`, `:session`, `:user_account`, `:student` and `:preregistered_user`.
  Use it as `setup :register_and_log_in_student`.

  When called directly (rather than as a `setup` hook), `overrides` may carry
  `:user_account`, `:student` and `:session` keyword lists that are merged into
  the respective factory builds.
  """
  @spec register_and_log_in_student(
          %{:conn => Conn.t(), optional(atom()) => term()},
          keyword()
        ) :: logged_in_student_context()
  def register_and_log_in_student(context, overrides! \\ [])

  def register_and_log_in_student(%{conn: conn}, overrides!) when is_list(overrides!) do
    {student_overrides, overrides!} = Keyword.pop(overrides!, :student, [])
    {user_account_overrides, session_overrides} = split_login_overrides(overrides!)

    student = CourseFactory.build(:student, Keyword.merge([user: nil], student_overrides))
    preregistered_user = AccountsFactory.build(:preregistered_user, id: student.id)

    user_account =
      AccountsFactory.build(
        :user_account,
        Keyword.merge(
          [root: false, active: true, preregistered_user: preregistered_user],
          user_account_overrides
        )
      )

    user_account
    |> log_in_user_account(conn, session_overrides)
    |> Map.merge(%{student: student, preregistered_user: preregistered_user})
  end

  @doc """
  Puts a session token into the connection's test session, as the
  `fetch_authentication` plug expects to find it.
  """
  @spec put_user_token_in_session(Conn.t(), String.t()) :: Conn.t()
  def put_user_token_in_session(conn, token) when is_binary(token),
    do: init_test_session(conn, %{session_token: token})

  @doc """
  Puts a session token into the connection's signed remember-me cookie, as the
  `fetch_authentication` plug expects to find it when the session has none.
  """
  @spec put_user_token_in_remember_me_cookie(Conn.t(), String.t()) :: Conn.t()
  def put_user_token_in_remember_me_cookie(conn, token) when is_binary(token),
    do:
      put_req_cookie(
        conn,
        @remember_me_cookie,
        Crypto.sign(secret_key_base(), @remember_me_cookie <> "_cookie", token,
          keys: Plug.Keys,
          max_age: 60
        )
      )

  @doc """
  Returns the application's configured secret key base.
  """
  @spec secret_key_base() :: String.t()
  def secret_key_base,
    do: :archidep |> Application.fetch_env!(Endpoint) |> Keyword.fetch!(:secret_key_base)

  defp split_login_overrides(overrides!) do
    {user_account_overrides, overrides!} = Keyword.pop(overrides!, :user_account, [])
    {session_overrides, overrides!} = Keyword.pop(overrides!, :session, [])
    [] = Keyword.keys(overrides!)
    {user_account_overrides, session_overrides}
  end

  defp log_in_user_account(user_account, conn, session_overrides) do
    session =
      AccountsFactory.build(
        :user_session,
        Keyword.merge(
          [
            user_account: user_account,
            client_user_agent: Factory.user_agent(),
            impersonated_user_account: nil
          ],
          session_overrides
        )
      )

    conn_with_auth(conn, session: session)
  end

  defp live_socket_id(session), do: "auth:#{session.user_account_id}"
end
