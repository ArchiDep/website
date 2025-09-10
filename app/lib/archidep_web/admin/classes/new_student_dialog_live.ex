defmodule ArchiDepWeb.Admin.Classes.NewStudentDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.StudentFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDepWeb.Admin.Classes.StudentForm

  @id "new-student-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec close() :: js
  def close, do: close_dialog(@id)

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        class: assigns.class,
        form: to_form(StudentForm.create_changeset(%{}), as: :student)
      )
      |> ok()

  @impl LiveComponent
  def handle_event("closed", _params, socket) do
    socket
    |> assign(form: to_form(StudentForm.create_changeset(%{}), as: :student))
    |> noreply()
  end

  @impl LiveComponent
  def handle_event("validate", %{"student" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    validate_dialog_form(
      :student,
      StudentForm.create_changeset(params),
      fn data ->
        Course.validate_student(auth, class.id, StudentForm.to_student_data(data))
      end,
      socket
    )
  end

  @impl LiveComponent
  def handle_event("create", %{"student" => params}, socket) do
    auth = socket.assigns.auth
    class = socket.assigns.class

    with {:ok, form_data} <-
           Changeset.apply_action(StudentForm.create_changeset(params), :validate),
         {:ok, created_student} <-
           Course.create_student(
             auth,
             class.id,
             StudentForm.to_student_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(:success, gettext("Created student {student}", student: created_student.name))
      )
      |> push_event("execute-action", %{to: "##{id()}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :student)) |> noreply()
    end
  end
end
