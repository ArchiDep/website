defmodule ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Student

  @base_id "delete-student-dialog"

  @spec id(Student.t()) :: String.t()
  def id(student), do: "#{@base_id}-#{student.id}"

  @spec close(Student.t()) :: js
  def close(student), do: student |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        student: assigns.student
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket), do: {:noreply, socket}

  def handle_event("delete", _params, socket) do
    auth = socket.assigns.auth
    student = socket.assigns.student

    with :ok <- Students.delete_student(auth, student.id) do
      noreply(socket)
    end
  end
end
