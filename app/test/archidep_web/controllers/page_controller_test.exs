defmodule ArchiDepWeb.Controllers.PageControllerTest do
  use ArchiDepWeb.Support.ConnCase

  test "GET /app", %{conn: conn} do
    conn = get(conn, ~p"/app")
    assert redirected_to(conn) =~ "/login"
  end
end
