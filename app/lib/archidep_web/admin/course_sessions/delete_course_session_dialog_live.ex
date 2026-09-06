defmodule ArchiDepWeb.Admin.CourseSessions.DeleteCourseSessionDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.CourseSession

  @base_id "delete-course-session-dialog"

  @spec id(CourseSession.t()) :: String.t()
  def id(%CourseSession{id: id}), do: "#{@base_id}-#{id}"

  @spec close(CourseSession.t()) :: js
  def close(course_session), do: course_session |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket), do: socket |> assign(assigns) |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket), do: noreply(socket)

  def handle_event("delete", _params, socket) do
    auth = socket.assigns.auth
    course_session = socket.assigns.course_session

    :ok = Course.delete_course_session(auth, course_session.id)

    socket
    |> send_notification(
      Message.new(
        :success,
        gettext("Deleted the session of {date}", date: Date.to_iso8601(course_session.date))
      )
    )
    |> noreply()
  end
end
