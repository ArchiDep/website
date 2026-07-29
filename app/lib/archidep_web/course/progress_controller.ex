defmodule ArchiDepWeb.Course.ProgressController do
  @moduledoc false

  use ArchiDepWeb, :controller

  alias ArchiDep.Course
  alias ArchiDep.CourseSite.Session
  alias Plug.Conn

  @spec progress(Conn.t(), map) :: Conn.t()
  def progress(conn, _params) do
    json(conn, %{sessions: Enum.map(Course.course_sessions(), &session/1)})
  end

  defp session(%Session{date: date, title: title, done: done, due: due, next: next}),
    do: %{date: Date.to_iso8601(date), title: title, done: done, due: due, next: next}
end
