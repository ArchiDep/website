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
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.DataCase
  alias ArchiDep.Support.Factory
  alias Phoenix.ConnTest
  alias Plug.Conn

  @type conn_with_auth_session_option :: {:session, UserSession.t()}
  @type conn_with_auth_option :: conn_with_auth_session_option()

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

  defp live_socket_id(session), do: "auth:#{session.user_account_id}"
end
