defmodule ArchiDepWeb.PageControllerTest do
  use ArchiDepWeb.ConnCase

  test "GET /app", %{conn: conn} do
    conn = get(conn, ~p"/app")
    assert html_response(conn, 200) =~ "ArchiDep"
  end
end
