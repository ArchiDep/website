defmodule ArchiDepWeb.CourseSitePagesTest do
  @moduledoc """
  This plug is driven directly rather than [through a
  route](../../docs/testing.md#plumbing-router-plugs-auth). That is a standing,
  explicitly authorised departure from that rule rather than an oversight: the
  plug is in the endpoint's pipeline only where a course material build is
  configured, and neither a build nor static serving is configured in the test
  environment, so no request can reach it.
  """

  use ExUnit.Case, async: true

  alias ArchiDepWeb.CourseSitePages

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "index.html", "<html><body>The course</body></html>")
    write!(tmp_dir, "course/507-dns/index.html", "<html><body>DNS</body></html>")
    write!(tmp_dir, "2025/course/507-dns/index.html", "<html><body>DNS in 2025</body></html>")
    write!(tmp_dir, "course/507-dns/images/zone-9f8e.png", "a picture")
    write!(Path.dirname(tmp_dir), "secret.html", "not part of the build")

    %{opts: CourseSitePages.init(from: tmp_dir)}
  end

  describe "call/2" do
    test "sends a page of the build as a body the live reloader can reach", %{opts: opts} do
      assert response(:get, "/course/507-dns/index.html", opts) == %{
               status: 200,
               content_type: "text/html; charset=utf-8",
               cache_control: "no-cache",
               body: "<html><body>DNS</body></html>",
               halted: true
             }
    end

    # A build writes into the directory its mount point names, so the edition it
    # holds is a directory of that one and needs nothing said about it here.
    test "sends a page of the edition the build holds", %{opts: opts} do
      assert response(:get, "/2025/course/507-dns/index.html", opts) == %{
               status: 200,
               content_type: "text/html; charset=utf-8",
               cache_control: "no-cache",
               body: "<html><body>DNS in 2025</body></html>",
               halted: true
             }
    end

    test "sends the home page of the build", %{opts: opts} do
      assert response(:get, "/index.html", opts) == %{
               status: 200,
               content_type: "text/html; charset=utf-8",
               cache_control: "no-cache",
               body: "<html><body>The course</body></html>",
               halted: true
             }
    end

    test "answers a HEAD with the headers of the page and no body", %{opts: opts} do
      assert response(:head, "/index.html", opts) == %{
               status: 200,
               content_type: "text/html; charset=utf-8",
               cache_control: "no-cache",
               body: "",
               halted: true
             }
    end

    test "passes anything that is not a page on to the plugs behind it", %{opts: opts} do
      assert response(:get, "/course/507-dns/images/zone-9f8e.png", opts) == untouched()
    end

    test "passes a page the build never wrote on", %{opts: opts} do
      assert response(:get, "/course/nowhere/index.html", opts) == untouched()
    end

    test "passes a request for the directory itself on", %{opts: opts} do
      assert response(:get, "/course/507-dns/", opts) == untouched()
    end

    test "refuses to walk out of the build", %{opts: opts} do
      assert response(:get, "/../secret.html", opts) == untouched()
    end

    test "passes anything that is not a GET or a HEAD on", %{opts: opts} do
      assert response(:post, "/index.html", opts) == untouched()
    end
  end

  defp response(method, path, opts) do
    conn = CourseSitePages.call(Plug.Test.conn(method, path), opts)

    %{
      status: conn.status,
      content_type: header(conn, "content-type"),
      cache_control: header(conn, "cache-control"),
      body: conn.resp_body,
      halted: conn.halted
    }
  end

  # What the plug leaves a connection it has nothing to say about: untouched, so
  # that the `Plug.Static` behind it answers instead. The cache-control is the
  # one `Plug.Test.conn/2` seeds every connection with, which is how a
  # connection that was left alone tells itself apart from one that was
  # answered.
  defp untouched,
    do: %{
      status: nil,
      content_type: nil,
      cache_control: "max-age=0, private, must-revalidate",
      body: nil,
      halted: false
    }

  defp header(conn, name) do
    case Plug.Conn.get_resp_header(conn, name) do
      [value] -> value
      [] -> nil
    end
  end

  defp write!(root, path, contents) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, contents)
  end
end
