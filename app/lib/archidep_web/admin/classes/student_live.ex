defmodule ArchiDepWeb.Admin.Classes.StudentLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDepWeb.Admin.Classes.DeleteStudentDialogLive
  alias ArchiDepWeb.Admin.Classes.EditStudentDialogLive

  @impl LiveView
  def mount(%{"class_id" => class_id, "id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Course.fetch_student_in_class(auth, class_id, id) do
      {:ok, student} ->
        active_server = find_active_server(student)

        if connected?(socket) do
          set_process_label(__MODULE__, auth, student)

          :ok = Accounts.PubSub.subscribe_preregistered_user(id)
          :ok = Course.PubSub.subscribe_student(student.id)
          :ok = Course.PubSub.subscribe_class(student.class_id)

          if student.user_id do
            :ok = Servers.PubSub.subscribe_server_owner_servers(student.user_id)
          end
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
            student: %Student{id: id} = student,
            active_server: active_server
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          student: Student.refresh!(student, updated_student),
          active_server:
            active_server
            |> maybe_refresh_server_group_member(updated_student)
            |> maybe_drop_active_server()
        )
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
          assigns: %{
            student: %Student{class: %Class{id: class_id} = class} = student,
            active_server: active_server
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          student: %Student{student | class: Class.refresh!(class, updated_class)},
          active_server:
            active_server
            |> maybe_refresh_server_group(updated_class, student)
            |> maybe_drop_active_server()
        )
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

    if refreshed.user_id != nil and refreshed.user_id != student.user_id do
      :ok = Servers.PubSub.subscribe_server_owner_servers(refreshed.user_id)
    end

    socket |> assign(student: refreshed) |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_created, created_server},
        %Socket{assigns: %{active_server: active_server}} = socket
      ) do
    if Server.active?(created_server, DateTime.utc_now()) and active_server == nil do
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
        {:server_updated, updated_server},
        %Socket{assigns: %{active_server: active_server}} = socket
      ) do
    if Server.active?(updated_server, DateTime.utc_now()) and
         (active_server == nil or active_server.id == updated_server.id) do
      socket
      |> assign(
        active_server:
          if(active_server,
            do: Server.refresh!(active_server, updated_server),
            else: updated_server
          )
      )
      |> noreply()
    else
      socket
      |> assign(active_server: nil)
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, %Server{id: server_id}},
        %Socket{assigns: %{active_server: %Server{id: server_id}}} = socket
      ) do
    socket
    |> assign(active_server: nil)
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, _deleted_server},
        %Socket{assigns: %{active_server: nil}} = socket
      ) do
    noreply(socket)
  end

  defp find_active_server(student) do
    case Server.find_active_server_for_group_member(student.id) do
      {:ok, server} -> server
      {:error, _any_reason} -> nil
    end
  end

  defp maybe_drop_active_server(nil), do: nil

  defp maybe_drop_active_server(server),
    do: if(Server.active?(server, DateTime.utc_now()), do: server, else: nil)

  defp maybe_refresh_server_group(nil, updated_class, student) do
    if Class.active?(updated_class, DateTime.utc_now()) do
      find_active_server(student)
    else
      nil
    end
  end

  defp maybe_refresh_server_group(server, updated_class, _student),
    do: %Server{server | group: ServerGroup.refresh!(server.group, updated_class)}

  defp maybe_refresh_server_group_member(nil, updated_student) do
    if Student.active?(updated_student, DateTime.utc_now()) do
      find_active_server(updated_student)
    else
      nil
    end
  end

  defp maybe_refresh_server_group_member(
         %Server{owner: %ServerOwner{group_member: %ServerGroupMember{id: id} = member}} = server,
         %Student{id: id} = updated_student
       ),
       do: %Server{
         server
         | owner: %ServerOwner{
             server.owner
             | group_member: ServerGroupMember.refresh!(member, updated_student)
           }
       }
end
