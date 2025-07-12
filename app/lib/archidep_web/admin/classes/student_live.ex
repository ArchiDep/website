defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Students
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class
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
        :ok = PubSub.subscribe_class(student.class_id)
        :ok = Accounts.PubSub.subscribe_preregistered_user(student.id)
      end

      socket
      |> assign(
        page_title:
          "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Classes")} > #{student.class.name} > #{student.name}",
        class: student.class,
        student: student
      )
      |> ok()
    else
      {:error, :student_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Student not found")))
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
        |> put_notification(
          Message.new(
            :success,
            gettext("Deleted student {student}", student: deleted_student.name)
          )
        )
        |> push_navigate(to: ~p"/admin/classes/#{deleted_student.class_id}")
        |> noreply()

  @impl true
  def handle_info(
        {:class_updated, %Class{id: class_id} = updated_class},
        %Socket{
          assigns: %{student: %Student{class: %Class{id: class_id} = class}}
        } = socket
      ),
      do:
        socket
        |> assign(student: %Student{class: Class.refresh!(class, updated_class)})
        |> noreply()

  @impl true
  def handle_info(
        {:class_deleted, %Class{id: class_id}},
        %Socket{
          assigns: %{student: %Student{class: %Class{id: class_id, name: class_name}}}
        } = socket
      ),
      do:
        socket
        |> put_notification(
          Message.new(
            :warning,
            gettext("Class {class} has been deleted", class: class_name)
          )
        )
        |> push_navigate(to: ~p"/admin/classes")
        |> noreply()

  @impl true
  def handle_info(
        {:preregistered_user_updated, %{id: id} = update},
        %Socket{
          assigns: %{student: %Student{id: id} = student}
        } = socket
      ) do
    refreshed = Student.refresh!(student, update)
    socket |> assign(student: refreshed) |> noreply()
  end
end
