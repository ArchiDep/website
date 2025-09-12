defmodule ArchiDepWeb.PageControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  test "GET /app", %{conn: conn} do
    conn = get(conn, ~p"/app")
    assert redirected_to(conn) =~ "/login"
  end
end
