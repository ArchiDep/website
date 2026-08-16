defmodule ArchiDepWeb.CourseSitePages do
  @moduledoc """
  Serving the pages of a course material build with a body, so that the live
  reloader can reach them.

  `Phoenix.LiveReloader` injects its script from a `before_send` callback
  guarded by the response having a body, and `Plug.Static` answers with
  `Plug.Conn.send_file/5`, which leaves it empty. So a page served the ordinary
  way can never reload itself, however the build got there.

  Reading a whole page into memory to send it is exactly what `Plug.Static`
  avoids and exactly what is wanted here: the pages are tens of kilobytes, and
  this is only ever in the pipeline of a development server. Everything else the
  build published — the images, the stylesheets, the decks' own assets — falls
  through to the `Plug.Static` behind this one.
  """

  @behaviour Plug

  import Plug.Conn

  @page_extension ".html"

  @impl Plug
  def init(opts), do: Keyword.fetch!(opts, :from)

  @impl Plug
  def call(%Plug.Conn{method: method, path_info: path_info} = conn, from)
      when method in ["GET", "HEAD"] and path_info != [] do
    with true <- page?(List.last(path_info)),
         {:ok, path} <- path_info |> Path.join() |> Path.safe_relative(),
         {:ok, html} <- from |> Path.join(path) |> File.read() do
      conn
      |> put_resp_content_type("text/html")
      # A page is not a file with a name that changes when it does, and the
      # build behind it is rewritten every time a document is saved, so a
      # browser must ask again rather than decide for itself.
      |> put_resp_header("cache-control", "no-cache")
      |> send_resp(200, html)
      |> halt()
    else
      _anything_else -> conn
    end
  end

  def call(%Plug.Conn{} = conn, _from), do: conn

  defp page?(segment), do: Path.extname(segment) == @page_extension
end
