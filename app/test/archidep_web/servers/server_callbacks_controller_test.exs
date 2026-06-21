defmodule ArchiDepWeb.Servers.ServerCallbacksControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import Hammox
  alias ArchiDep.Servers
  alias Ecto.UUID

  setup :verify_on_exit!

  describe "POST /api/callbacks/servers/:server_id/up" do
    test "accept the callback when the server notification succeeds", %{conn: conn} do
      server_id = UUID.generate()
      token = "secret-callback-token"

      expect(Servers.ContextMock, :notify_server_up, 1, fn ^server_id, ^token -> :ok end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/callbacks/servers/#{server_id}/up")

      assert response(conn, 202) == ""
    end

    test "reject the callback when the server is not found", %{conn: conn} do
      server_id = UUID.generate()
      token = "secret-callback-token"

      expect(Servers.ContextMock, :notify_server_up, 1, fn ^server_id, ^token ->
        {:error, :server_not_found}
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/callbacks/servers/#{server_id}/up")

      assert response(conn, 401) == ""
    end

    test "reject the callback when the authorization header is missing", %{conn: conn} do
      server_id = UUID.generate()

      # No expectation is set on the context mock, so verify_on_exit! proves the
      # server notification is never attempted when the bearer token is absent.
      conn = post(conn, ~p"/api/callbacks/servers/#{server_id}/up")

      assert response(conn, 401) == ""
    end

    test "reject the callback when the authorization header is not a bearer token", %{conn: conn} do
      server_id = UUID.generate()

      conn =
        conn
        |> put_req_header("authorization", "token-only")
        |> post(~p"/api/callbacks/servers/#{server_id}/up")

      assert response(conn, 401) == ""
    end

    test "reject the callback when several authorization headers are sent", %{conn: conn} do
      server_id = UUID.generate()

      conn =
        conn
        |> prepend_req_headers([
          {"authorization", "Bearer first-token"},
          {"authorization", "Bearer second-token"}
        ])
        |> post(~p"/api/callbacks/servers/#{server_id}/up")

      assert response(conn, 401) == ""
    end
  end
end
