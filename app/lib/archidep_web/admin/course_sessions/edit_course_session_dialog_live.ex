defmodule ArchiDepWeb.Admin.CourseSessions.EditCourseSessionDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.CourseSessions.CourseSessionFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.CourseSession
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionForm
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid

  @base_id "edit-course-session-dialog"

  @spec id(CourseSession.t()) :: String.t()
  def id(%CourseSession{id: id}), do: "#{@base_id}-#{id}"

  @spec close(CourseSession.t()) :: js
  def close(course_session), do: course_session |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket) do
    course_session = assigns.course_session

    socket
    |> assign(assigns)
    |> assign(
      form:
        to_form(
          CourseSessionForm.update_changeset(course_session, %{}),
          form_opts(course_session)
        ),
      rows: CourseSessionGrid.rows(course_session)
    )
    |> ok()
  end

  # Every session on the page has a form of its own, so the inputs need ids of
  # their own too.
  defp form_opts(%CourseSession{id: id}), do: [as: :course_session, id: "#{@base_id}-#{id}"]

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(
        form:
          to_form(
            CourseSessionForm.update_changeset(socket.assigns.course_session, %{}),
            form_opts(socket.assigns.course_session)
          )
      )
      |> noreply()

  def handle_event("validate", %{"course_session" => params}, socket) do
    auth = socket.assigns.auth
    course_session = socket.assigns.course_session

    changeset = CourseSessionForm.update_changeset(course_session, params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, result_changeset} <-
           Course.validate_existing_course_session(
             auth,
             course_session.id,
             CourseSessionForm.to_course_session_data(form_data)
           ) do
      socket
      |> assign(
        form:
          to_form(
            %Changeset{changeset | errors: result_changeset.errors},
            form_opts(course_session) ++ [action: :validate]
          )
      )
      |> noreply()
    else
      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(
              %Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              form_opts(course_session)
            )
        )
        |> noreply()
    end
  end

  def handle_event("update", %{"course_session" => params}, socket) do
    auth = socket.assigns.auth
    course_session = socket.assigns.course_session

    changeset = CourseSessionForm.update_changeset(course_session, params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, updated_course_session} <-
           Course.update_course_session(
             auth,
             course_session.id,
             CourseSessionForm.to_course_session_data(form_data)
           ) do
      # The dialog closes immediately below; the updated session flows back in
      # through the parent's PubSub refresh, so the form is reset from what the
      # page holds rather than from what was just written.
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Updated the session of {date}",
            date: Date.to_iso8601(updated_course_session.date)
          )
        )
      )
      |> push_event("execute-action", %{to: "##{id(course_session)}", action: "close"})
      |> assign(
        form:
          to_form(
            CourseSessionForm.update_changeset(course_session, %{}),
            form_opts(course_session)
          )
      )
      |> noreply()
    else
      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(
              %Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              form_opts(course_session) ++ [action: :update]
            )
        )
        |> noreply()
    end
  end
end
