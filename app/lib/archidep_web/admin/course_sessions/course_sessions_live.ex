defmodule ArchiDepWeb.Admin.CourseSessions.CourseSessionsLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.CourseSiteRebuilder
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid
  alias ArchiDepWeb.Admin.CourseSessions.DeleteCourseSessionDialogLive
  alias ArchiDepWeb.Admin.CourseSessions.EditCourseSessionDialogLive
  alias ArchiDepWeb.Admin.CourseSessions.NewCourseSessionDialogLive
  alias ArchiDepWeb.LiveRefresh

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    socket
    |> assign(
      page_title: "#{gettext("Course progress")} · #{gettext("Admin")}",
      course_sessions: Course.list_course_sessions(auth),
      # What came of the last build this page saw. Editing a session renders the
      # site again, and a build that fails changes nothing and says so only in
      # the log — the static server goes on serving what it already had — so the
      # page that caused it is where that has to be visible.
      last_build: nil
    )
    |> track_course_sessions(auth)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)

  @impl LiveView
  def handle_info({:course_site_built, outcome}, socket),
    do: socket |> assign(last_build: outcome) |> noreply()

  # On connected mount, keep the list current through the Course boundary. The
  # refresher owns create, update, delete and ordering, so this page names no
  # topics or events of that context; the builds it causes are not a context's,
  # and are subscribed to directly.
  defp track_course_sessions(socket, auth) do
    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = Course.subscribe_course_sessions()
      :ok = CourseSiteRebuilder.subscribe_builds()
      LiveRefresh.attach(socket, :course_sessions, &Course.refresh_course_sessions(auth, &1, &2))
    else
      socket
    end
  end
end
