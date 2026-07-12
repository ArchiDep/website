defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive

  @impl LiveView
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Course.fetch_student_in_class(auth, class_id, id) do
      {:ok, student} ->
        active_server = find_active_server(auth, student)

        if connected?(socket) do
          set_process_label(__MODULE__, auth, student)
          subscribe(student)
        end

        socket
        |> assign(
          page_title: "#{student.name} · #{student.class.name} · #{gettext("Admin")}",
          class: student.class,
          student: student,
          active_server: active_server,
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

  defp subscribe(student) do
    :ok = Accounts.PubSub.subscribe_preregistered_user(student.id)
    :ok = Course.PubSub.subscribe_student(student.id)
    :ok = Course.PubSub.subscribe_class(student.class_id)

    if student.user_id do
      :ok = Servers.PubSub.subscribe_server_owner_servers(student.user_id)
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
        {:student_updated, %{id: id} = event, reference},
        %Socket{
          assigns: %{
            auth: auth,
            student: %Student{id: id} = student,
            active_server: active_server
          }
        } = socket
      ) do
    refreshed_student = Student.refresh!(student, event, reference)

    socket
    |> assign(
      student: refreshed_student,
      active_server:
        active_server
        |> maybe_refresh_server_group_member(auth, event, reference, refreshed_student)
        |> maybe_drop_active_server()
    )
    |> noreply()
  end

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
        {:class_updated, event, reference},
        %Socket{
          assigns: %{
            auth: auth,
            student: %Student{class: %Class{} = class} = student,
            active_server: active_server
          }
        } = socket
      ) do
    refreshed_class = Class.refresh!(class, event, reference)

    socket
    |> assign(
      student: %Student{student | class: refreshed_class},
      active_server:
        active_server
        |> maybe_refresh_server_group(auth, event, reference, refreshed_class, student)
        |> maybe_drop_active_server()
    )
    |> noreply()
  end

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
        {:preregistered_user_updated, %{preregistered_user_id: id} = event, reference},
        %Socket{
          assigns: %{student: %Student{id: id} = student}
        } = socket
      ) do
    refreshed = Student.refresh!(student, event, reference)

    if refreshed.user_id != nil and refreshed.user_id != student.user_id do
      :ok = Servers.PubSub.subscribe_server_owner_servers(refreshed.user_id)
    end

    socket |> assign(student: refreshed) |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_created, %{id: server_id}, _reference},
        %Socket{assigns: %{auth: auth, active_server: active_server}} = socket
      ) do
    created_server =
      case Servers.fetch_server(auth, server_id) do
        {:ok, server} -> server
        {:error, _reason} -> nil
      end

    if created_server != nil and ServerView.active?(created_server, Clock.now()) and
         active_server == nil do
      socket
      |> assign(active_server: created_server)
      |> noreply()
    else
      socket
      |> assign(active_server: nil)
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:server_updated, event, reference},
        %Socket{assigns: %{auth: auth, active_server: active_server}} = socket
      ) do
    updated_server =
      if active_server != nil and active_server.id == event.id do
        ServerView.refresh!(active_server, event, reference)
      else
        case Servers.fetch_server(auth, event.id) do
          {:ok, server} -> server
          {:error, _reason} -> nil
        end
      end

    if updated_server != nil and ServerView.active?(updated_server, Clock.now()) and
         (active_server == nil or active_server.id == updated_server.id) do
      socket
      |> assign(active_server: updated_server)
      |> noreply()
    else
      socket
      |> assign(active_server: nil)
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, %ServerDeleted{id: server_id}, _reference},
        %Socket{assigns: %{active_server: %ServerView{id: server_id}}} = socket
      ) do
    socket
    |> assign(active_server: nil)
    |> noreply()
  end

  @impl LiveView
  def handle_info({:server_deleted, %ServerDeleted{}, _reference}, socket) do
    noreply(socket)
  end

  defp find_active_server(auth, student) do
    case Servers.fetch_active_server_for_group_member(auth, student.id) do
      {:ok, server} -> server
      {:error, _any_reason} -> nil
    end
  end

  defp maybe_drop_active_server(nil), do: nil

  defp maybe_drop_active_server(server),
    do: if(ServerView.active?(server, Clock.now()), do: server, else: nil)

  defp maybe_refresh_server_group(
         nil,
         auth,
         _event,
         _reference,
         %Class{} = refreshed_class,
         student
       ) do
    if Class.active?(refreshed_class, Clock.now()) do
      find_active_server(auth, student)
    else
      nil
    end
  end

  defp maybe_refresh_server_group(
         %ServerView{} = server,
         _auth,
         event,
         reference,
         _refreshed_class,
         _student
       ),
       do: ServerView.refresh!(server, event, reference)

  defp maybe_refresh_server_group_member(nil, auth, _event, _reference, refreshed_student) do
    if Student.active?(refreshed_student, Clock.now()) do
      find_active_server(auth, refreshed_student)
    else
      nil
    end
  end

  defp maybe_refresh_server_group_member(
         %ServerView{owner: %ServerOwner{group_member: %ServerGroupMember{id: id}}} = server,
         _auth,
         %{id: id} = event,
         reference,
         _refreshed_student
       ),
       do: ServerView.refresh!(server, event, reference)
end
