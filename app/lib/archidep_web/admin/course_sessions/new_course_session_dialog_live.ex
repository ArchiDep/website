defmodule ArchiDepWeb.Admin.CourseSessions.NewCourseSessionDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.CourseSessions.CourseSessionFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionForm
  alias ArchiDepWeb.Admin.CourseSessions.CourseSessionGrid

  @id "new-course-session-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @impl LiveComponent
  def mount(socket), do: socket |> assign(form: blank_form()) |> ok()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(assigns)
      # What is left to record depends on what has been recorded, so the grid
      # follows the list the page holds rather than being fixed on mount: a
      # session recorded here or elsewhere takes what it marked done out of the
      # form the next one starts from.
      |> assign(rows: CourseSessionGrid.unfinished_rows(assigns.course_sessions))
      |> ok()

  defp blank_form,
    do:
      Clock.now()
      |> DateTime.to_date()
      |> CourseSessionForm.initial_changeset()
      |> to_form(as: :course_session, id: @id)

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do: socket |> assign(form: blank_form()) |> noreply()

  def handle_event("validate", %{"course_session" => params}, socket) do
    auth = socket.assigns.auth

    changeset = CourseSessionForm.create_changeset(params)

    case Changeset.apply_action(changeset, :validate) do
      {:ok, form_data} ->
        course_session_changeset =
          Course.validate_course_session(
            auth,
            CourseSessionForm.to_course_session_data(form_data)
          )

        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: course_session_changeset.errors},
              as: :course_session,
              id: @id,
              action: :validate
            )
        )
        |> noreply()

      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              as: :course_session,
              id: @id
            )
        )
        |> noreply()
    end
  end

  def handle_event("create", %{"course_session" => params}, socket) do
    auth = socket.assigns.auth

    changeset = CourseSessionForm.create_changeset(params)

    with {:ok, form_data} <- Changeset.apply_action(changeset, :validate),
         {:ok, created_course_session} <-
           Course.create_course_session(
             auth,
             CourseSessionForm.to_course_session_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Recorded the session of {date}",
            date: Date.to_iso8601(created_course_session.date)
          )
        )
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = result_changeset} ->
        socket
        |> assign(
          form:
            to_form(%Changeset{changeset | errors: changeset.errors ++ result_changeset.errors},
              as: :course_session,
              id: @id,
              action: :insert
            )
        )
        |> noreply()
    end
  end
end
