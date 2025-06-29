defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive

  @impl true
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    with {:ok, student} <- Students.fetch_student_in_class(auth, class_id, id) do
      if connected?(socket) do
        set_process_label(__MODULE__, auth, student)
        :ok = PubSub.subscribe_student(student.id)
      end

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
        |> put_notification(Message.new(:error, "Student not found"))
        |> push_navigate(to: ~p"/admin/classes/#{class_id}")
        |> ok()
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:student_updated, %Student{id: student_id} = updated_student},
        %Socket{
          assigns: %{student: %Student{id: student_id}}
        } = socket
      ),
      do: socket |> assign(student: updated_student) |> noreply()

  @impl true
  def handle_info(
        {:student_deleted, %Student{id: student_id} = deleted_student},
        %Socket{
          assigns: %{student: %Student{id: student_id}}
        } = socket
      ),
      do:
        socket
        |> put_notification(Message.new(:success, "Deleted student #{deleted_student.name}"))
        |> push_navigate(to: ~p"/admin/classes/#{deleted_student.class_id}")
        |> noreply()
end
