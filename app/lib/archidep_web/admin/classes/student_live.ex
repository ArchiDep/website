defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive

  @impl LiveView
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Course.fetch_student_in_class(auth, class_id, id) do
      {:ok, student} ->
        if connected?(socket) do
          set_process_label(__MODULE__, auth, student)
          :ok = PubSub.subscribe_student(student.id)
          :ok = PubSub.subscribe_class(student.class_id)
          :ok = Accounts.PubSub.subscribe_preregistered_user(id)
        end

        socket
        |> assign(
          page_title: "#{student.name} · #{student.class.name} · #{gettext("Admin")}",
          class: student.class,
          student: student,
          login_link: nil
        )
        |> ok()

      {:error, :student_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Student not found")))
        |> push_navigate(to: ~p"/admin/classes/#{class_id}")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl LiveView
  def handle_event(
        "generate-login-link",
        _params,
        %Socket{assigns: %{auth: auth, student: student}} = socket
      ) do
    case Accounts.create_login_link_for_preregistered_user(auth, student.id) do
      {:ok, login_link} ->
        socket
        |> assign(login_link: login_link)
        |> put_notification(Message.new(:success, gettext("Login link generated")))
        |> noreply()

      {:error, :preregistered_user_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Student not found")))
        |> push_navigate(to: ~p"/admin/classes/#{student.class_id}")
        |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:student_updated, %Student{id: id} = updated_student},
        %Socket{
          assigns: %{
            student: %Student{id: id} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: Student.refresh!(student, updated_student))
        |> noreply()

  @impl LiveView
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

  @impl LiveView
  def handle_info(
        {:class_updated, %Class{id: class_id} = updated_class, _event},
        %Socket{
          assigns: %{student: %Student{class: %Class{id: class_id} = class}}
        } = socket
      ),
      do:
        socket
        |> assign(student: %Student{class: Class.refresh!(class, updated_class)})
        |> noreply()

  @impl LiveView
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

  @impl LiveView
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
