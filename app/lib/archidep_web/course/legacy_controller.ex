defmodule ArchiDepWeb.Course.LegacyController do
  @moduledoc """
  Sends a reader who arrived at an unprefixed course material path to the
  edition that published it.

  The course material used to be served at the site root, so `/course/…` and
  `/cheatsheets/…` are the addresses of the 2025 edition and of no other. Every
  edition since lives under its own prefix, and those paths now hold nothing, so
  what is left of them is a permanent forwarding address.

  A reader is sent **into the archive** rather than to
  `ArchiDepWeb.Course.LatestController`: the archive is what the reader asked
  for, and it carries the banner that offers the current version of the page.
  Resolving the two steps at once would take that choice away.

  The redirect is **301 and cacheable for a year**, unlike the resolver's,
  because where the 2025 edition is published is settled forever. Saying so
  takes an explicit header: the `:browser` pipeline's secure browser headers
  tell a browser to revalidate everything, which is right for a page whose
  content can change and wrong for an address that cannot.
  """

  use ArchiDepWeb, :controller

  alias ArchiDep.CourseSite.PageRef
  alias Plug.Conn

  # The edition that was published unprefixed, which is a fact about what these
  # paths meant to the readers who kept them, not about the edition being taught
  # now. Reading the `version` knob would silently re-point every one of these
  # bookmarks at a different year's material the moment the course rolls over.
  @legacy_edition "2025"

  @index_file "/index.html"

  # A year, matching what the static server puts on the assets it serves.
  @cache_control "public, max-age=31536000"

  @doc """
  Redirect an unprefixed path to the same path under the edition that published
  it.

  The path is taken from the connection rather than from the route's glob
  because it is forwarded exactly as it was written, percent-encoding included;
  nothing here reads it.
  """
  @spec legacy(Conn.t(), map) :: Conn.t()
  def legacy(%Conn{request_path: request_path} = conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> put_resp_header("cache-control", @cache_control)
    |> redirect(to: PageRef.edition_path(@legacy_edition, page_path(request_path)))
  end

  # A redirect names the page, as the site publishes it, rather than the file
  # inside it — which is what `Plug.Static.IndexHtml` has already rewritten the
  # path to by the time a development request reaches the router, and would
  # otherwise make development emit a different permanent address than
  # production.
  defp page_path(request_path), do: String.replace_suffix(request_path, @index_file, "/")
end
