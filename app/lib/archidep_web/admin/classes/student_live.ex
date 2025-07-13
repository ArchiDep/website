defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.AdminComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive

  @impl true
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    with {:ok, student} <- Course.fetch_student_in_class(auth, class_id, id),
         {:ok, server_group_member} <- Servers.fetch_server_group_member(auth, id) do
      if connected?(socket) do
        set_process_label(__MODULE__, auth, student)
        :ok = PubSub.subscribe_student(student.id)
        :ok = PubSub.subscribe_class(student.class_id)
        :ok = Accounts.PubSub.subscribe_preregistered_user(id)
        :ok = Servers.PubSub.subscribe_server_group_member(id)
      end

      socket
      |> assign(
        page_title:
          "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Classes")} > #{student.class.name} > #{student.name}",
        class: student.class,
        student: student,
        server_group_member: server_group_member
      )
      |> ok()
    else
      {:error, not_found}
      when not_found in [:student_not_found, :server_group_member_not_found] ->
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
        {:student_updated, %Student{id: id} = updated_student},
        %Socket{
          assigns: %{
            student: %Student{id: id} = student,
            server_group_member: %ServerGroupMember{id: id} = member
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          student: Student.refresh!(student, updated_student),
          server_group_member: ServerGroupMember.refresh!(member, updated_student)
        )
        |> noreply()

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
        {:server_group_member_updated, %ServerGroupMember{id: id} = updated_member},
        %Socket{
          assigns: %{
            student: %Student{id: id} = student,
            server_group_member: %ServerGroupMember{id: id} = member
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          student: Student.refresh!(student, updated_member),
          server_group_member: ServerGroupMember.refresh!(member, updated_member)
        )
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
