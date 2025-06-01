defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive

  @impl LiveView
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    with {:ok, student} <- Students.fetch_student_in_class(socket.assigns.auth, class_id, id) do
      socket
      |> assign(
        page_title: "ArchiDep > Admin > Classes > #{student.class.name} > #{student.name}",
        class: student.class,
        student: student
      )
      |> ok()
    else
      {:error, :student_not_found} ->
        socket
        |> put_flash(:error, "Student not found")
        |> push_navigate(to: ~p"/admin/classes/#{class_id}")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
