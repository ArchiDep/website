defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Servers
  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive
  alias ArchiDepWeb.LiveRefresh

  @impl LiveView
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Course.fetch_student_in_class(auth, class_id, id) do
      {:ok, student} ->
        socket
        |> assign(
          page_title: "#{student.name} · #{student.class.name} · #{gettext("Admin")}",
          student: student,
          active_server: find_active_server(auth, student),
          login_link: nil
        )
        |> track(auth, student)
        |> ok()

      {:error, :student_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Student not found")))
        |> push_navigate(to: ~p"/admin/classes/#{class_id}")
        |> ok()
    end
  end

  # On connected mount, keep the student (with its nested class) and its active
  # server current through the Course and Servers boundaries. A single
  # `:student_updated` or `:class_updated` event feeds both, so the two share
  # one `attach_all` hook. The active server rides this student's server-owner
  # topic (see the linkage handler for the unlinked-then-linked case).
  defp track(socket, auth, student) do
    if connected?(socket) do
      set_process_label(__MODULE__, auth, student)
      :ok = Course.subscribe_student_detail(student)
      :ok = Servers.subscribe_active_server_for_member(student.user_id)

      LiveRefresh.attach_all(socket, [
        {:student, &Course.refresh_student_detail/2},
        {:active_server, &Servers.refresh_active_server_for_member(auth, student.id, &1, &2)}
      ])
    else
      socket
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

  # The student's account being (un)linked refreshes the student and, when an
  # account first appears, starts this process listening for that student's
  # server events — a process-local subscription that cannot live in a pure
  # refresher, so `refresh_student_detail` leaves this message to fall through.
  @impl LiveView
  def handle_info(
        {:preregistered_user_updated, %{preregistered_user_id: id} = event, reference},
        %Socket{
          assigns: %{student: %StudentView{id: id} = student}
        } = socket
      ) do
    refreshed = StudentView.refresh!(student, event, reference)

    if refreshed.user_id != nil and refreshed.user_id != student.user_id do
      :ok = Servers.subscribe_active_server_for_member(refreshed.user_id)
    end

    socket |> assign(student: refreshed) |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:student_deleted, %Student{id: student_id} = deleted_student},
        %Socket{
          assigns: %{student: %StudentView{id: student_id}}
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
        {:class_deleted, %Class{id: class_id}},
        %Socket{
          assigns: %{student: %StudentView{class: %ClassView{id: class_id, name: class_name}}}
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

  defp find_active_server(auth, student) do
    case Servers.fetch_active_server_for_group_member(auth, student.id) do
      {:ok, server} -> server
      {:error, _any_reason} -> nil
    end
  end
end
