defmodule ArchiDepWeb.Course.LegacyControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  describe "GET an unprefixed course material path" do
    test "sends a reader of a chapter into the edition that published it", %{conn: conn} do
      conn = get(conn, ~p"/course/402-run-virtual-server/")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/course/402-run-virtual-server/",
               cache_control: "public, max-age=31536000"
             }
    end

    test "sends a reader of a slide deck into the edition that published it", %{conn: conn} do
      conn = get(conn, ~p"/course/402-run-virtual-server/slides/")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/course/402-run-virtual-server/slides/",
               cache_control: "public, max-age=31536000"
             }
    end

    test "sends a reader of a cheatsheet into the edition that published it", %{conn: conn} do
      conn = get(conn, ~p"/cheatsheets/sysadmin/")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/cheatsheets/sysadmin/",
               cache_control: "public, max-age=31536000"
             }
    end

    test "sends a reader of a file beside a page to the same file", %{conn: conn} do
      conn = get(conn, ~p"/course/402-run-virtual-server/images/aws-console.png")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/course/402-run-virtual-server/images/aws-console.png",
               cache_control: "public, max-age=31536000"
             }
    end

    test "names the page rather than the file inside it", %{conn: conn} do
      conn = get(conn, ~p"/course/402-run-virtual-server/index.html")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/course/402-run-virtual-server/",
               cache_control: "public, max-age=31536000"
             }
    end

    test "sends a reader of a path no edition ever published, the archive answering for it", %{
      conn: conn
    } do
      conn = get(conn, ~p"/course/no-such-chapter/")

      assert redirection(conn) == %{
               status: 301,
               location: "/2025/course/no-such-chapter/",
               cache_control: "public, max-age=31536000"
             }
    end

    test "sends every reader to 2025 whatever edition is being taught", %{conn: conn} do
      conn = get(conn, ~p"/course/402-run-virtual-server/")

      # The edition this suite is configured to teach is asserted beside the
      # target, because it is what the target must not follow.
      assert {current_edition(), redirection(conn)} ==
               {"1955",
                %{
                  status: 301,
                  location: "/2025/course/402-run-virtual-server/",
                  cache_control: "public, max-age=31536000"
                }}
    end
  end

  defp current_edition,
    do: :archidep |> Application.fetch_env!(:course_site) |> Keyword.fetch!(:version)

  defp redirection(conn),
    do: %{
      status: conn.status,
      location: conn |> get_resp_header("location") |> Enum.join(", "),
      cache_control: conn |> get_resp_header("cache-control") |> Enum.join(", ")
    }
end
