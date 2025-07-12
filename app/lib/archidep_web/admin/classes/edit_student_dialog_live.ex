defmodule ArchiDepWeb.Admin.Classes.EditStudentDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Admin.Classes.StudentFormComponent
  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDepWeb.Admin.Classes.StudentForm

  @base_id "edit-student-dialog"

  @spec id(Student.t()) :: String.t()
  def id(%Student{id: id}), do: "#{@base_id}-#{id}"

  @spec close(Student.t()) :: js
  def close(student), do: student |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        student: assigns.student,
        form: to_form(StudentForm.update_changeset(assigns.student, %{}), as: :student)
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket),
    do:
      socket
      |> assign(
        form: to_form(StudentForm.update_changeset(socket.assigns.student, %{}), as: :student)
      )
      |> noreply()

  def handle_event("validate", %{"student" => params}, socket) do
    auth = socket.assigns.auth
    student = socket.assigns.student

    validate_dialog_form(
      :student,
      StudentForm.update_changeset(student, params),
      &Course.validate_existing_student(
        auth,
        student.id,
        StudentForm.to_existing_student_data(&1)
      ),
      socket
    )
  end

  def handle_event("update", %{"student" => params}, socket) do
    auth = socket.assigns.auth
    student = socket.assigns.student

    with {:ok, form_data} <-
           Changeset.apply_action(
             StudentForm.update_changeset(student, params),
             :validate
           ),
         {:ok, updated_student} <-
           Course.update_student(
             auth,
             student.id,
             StudentForm.to_existing_student_data(form_data)
           ) do
      socket
      |> send_notification(
        Message.new(
          :success,
          gettext("Updated student {student}", student: updated_student.name)
        )
      )
      |> push_event("execute-action", %{to: "##{id(student)}", action: "close"})
      |> noreply()
    else
      {:error, %Changeset{} = changeset} ->
        socket |> assign(form: to_form(changeset, as: :student)) |> noreply()
    end
  end
end
