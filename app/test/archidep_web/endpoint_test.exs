defmodule ArchiDepWeb.EndpointTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  alias ArchiDepWeb.Endpoint

  describe "the session cookie" do
    # Written on any browser response, `protect_from_forgery` putting the CSRF
    # token into the session being enough to make one. The login page is the
    # lightest route that does it and needs no principal.
    test "is flagged so a browser keeps it to this site and off plain HTTP", %{conn: conn} do
      conn = get(conn, ~p"/login")

      assert %{value: value} = conn.resp_cookies["_archidep_key"]
      assert is_binary(value) and value != ""

      # The header as the browser receives it, so the attributes Plug applies at
      # encode time rather than from the options are covered too. The value is
      # dropped: it is a signed payload, asserted above.
      assert session_cookie_attributes(conn) == ["path=/", "secure", "HttpOnly", "SameSite=Lax"]
    end
  end

  defp session_cookie_attributes(conn),
    do:
      conn
      |> get_resp_header("set-cookie")
      |> Enum.find(&String.starts_with?(&1, "_archidep_key="))
      |> String.split("; ")
      |> tl()

  describe "log_level/1" do
    test "disables logging for the health check route" do
      assert Endpoint.log_level(%{path_info: ["api", "health"]}) == false
    end

    test "logs any other route at the info level" do
      assert Endpoint.log_level(%{path_info: ["app"]}) == :info
      assert Endpoint.log_level(%{path_info: []}) == :info
    end
  end
end
