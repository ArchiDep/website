defmodule ArchiDepWeb.Course.LatestController do
  @moduledoc """
  Sends a reader who arrived from an archived edition of the course material to
  the page that superseded it.

  Every page of an archive carries this link, naming itself rather than its
  replacement, because what supersedes it changes as the course is reworked and
  the archive is frozen. `ArchiDep.CourseSite.Archives` holds the answer; this
  is the request that asks it.

  The redirect is **302 and never cached**: the target is a fact about the
  edition currently being taught, so a browser that remembered it would go on
  sending next year's readers to last year's page.
  """

  use ArchiDepWeb, :controller

  alias ArchiDep.CourseSite.Archives
  alias ArchiDepWeb.Helpers.CourseMaterialHelpers
  alias Plug.Conn

  @spec latest(Conn.t(), map) :: Conn.t()
  def latest(conn, params) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case Archives.resolve(Map.get(params, "to")) do
      {:ok, page} -> redirect(conn, to: CourseMaterialHelpers.course_url(page))
      {:gone, archived} -> no_equivalent(conn, archived)
      :error -> no_equivalent(conn, nil)
    end
  end

  # The link back is the key that matched — this application's own record of the
  # archive — rather than what the reader arrived with, which is never echoed.
  defp no_equivalent(conn, archived) do
    conn
    |> put_status(:not_found)
    |> render(:no_equivalent, archived: archived, home: CourseMaterialHelpers.course_url(:home))
  end
end
