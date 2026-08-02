defmodule ArchiDepWeb.Course.LatestControllerTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  import ArchiDepWeb.Support.HtmlTestHelpers
  import Hammox

  setup :verify_on_exit!

  describe "GET /latest" do
    test "sends a reader to the page the archived one became", %{conn: conn} do
      conn = get(conn, ~p"/latest?to=/2025/course/402-run-virtual-server/")

      assert {conn.status, redirected_to(conn), cache_control(conn)} ==
               {302, "/1955/course/402-run-virtual-server/", "no-store"}
    end

    test "reads a percent-encoded value exactly as a bare one", %{conn: conn} do
      encoded = get(conn, ~p"/latest?to=%2F2025%2Fcheatsheets%2Fsysadmin%2F")
      bare = get(conn, ~p"/latest?to=/2025/cheatsheets/sysadmin/")

      assert {encoded.status, redirected_to(encoded), cache_control(encoded)} ==
               {bare.status, redirected_to(bare), cache_control(bare)}
    end

    test "sends a reader of the archived home page to the current one", %{conn: conn} do
      conn = get(conn, ~p"/latest?to=/2025/")

      assert {conn.status, redirected_to(conn), cache_control(conn)} == {302, "/", "no-store"}
    end

    test "says so, and offers the course, when the value names no page we published", %{
      conn: conn
    } do
      conn = get(conn, ~p"/latest?to=/1999/course/402-run-virtual-server/")

      assert {conn.status, cache_control(conn), page(conn)} ==
               {404, "no-store",
                %{
                  heading: "This page is no longer part of the course",
                  reason:
                    "That link does not name a page of any edition of the course we have published.",
                  course_link: "/",
                  archived_link: nil
                }}
    end

    test "says the same of a value naming somewhere else entirely, and never redirects to it", %{
      conn: conn
    } do
      conn = get(conn, ~p"/latest?to=https://evil.example/2025/")

      assert {conn.status, cache_control(conn), page(conn)} ==
               {404, "no-store",
                %{
                  heading: "This page is no longer part of the course",
                  reason:
                    "That link does not name a page of any edition of the course we have published.",
                  course_link: "/",
                  archived_link: nil
                }}
    end

    test "says the same when asked for nothing at all", %{conn: conn} do
      conn = get(conn, ~p"/latest")

      assert {conn.status, cache_control(conn), page(conn)} ==
               {404, "no-store",
                %{
                  heading: "This page is no longer part of the course",
                  reason:
                    "That link does not name a page of any edition of the course we have published.",
                  course_link: "/",
                  archived_link: nil
                }}
    end
  end

  defp page(conn) do
    html = html_response(conn, conn.status)

    %{
      heading: text(html, "#no-equivalent h1"),
      reason: text(html, "#no-equivalent p"),
      course_link: href(html, "#current-course"),
      archived_link: href(html, "#archived-page")
    }
  end

  defp text(html, selector) do
    case find_html_elements(html, selector) do
      [] -> nil
      [element | _rest] -> html_element_text(element)
    end
  end

  defp href(html, selector) do
    case find_html_elements(html, selector) do
      [] -> nil
      [element | _rest] -> html_element_attribute(element, "href")
    end
  end

  defp cache_control(conn), do: conn |> get_resp_header("cache-control") |> Enum.join(", ")
end
