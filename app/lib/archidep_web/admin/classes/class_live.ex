defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassExpectedServerPropertiesDialogLive
  alias ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    [class_result, server_group_result] =
      Task.await_many([
        Task.async(fn -> Course.fetch_class(auth, id) end),
        Task.async(fn -> Servers.fetch_server_group(auth, id) end)
      ])

    with {:ok, class} <- class_result,
         {:ok, server_group} <- server_group_result do
      {server_ids, server_ids_reducer} =
        if connected?(socket) do
          set_process_label(__MODULE__, auth, class)
          :ok = Course.PubSub.subscribe_class(id)
          :ok = Course.PubSub.subscribe_class_students(id)
          :ok = Accounts.PubSub.subscribe_user_group_preregistered_users(id)
          {:ok, server_ids, server_ids_reducer} = Servers.watch_server_ids(auth, server_group)
          {server_ids, server_ids_reducer}
        else
          {MapSet.new(), fn ids, _event -> ids end}
        end

      socket
      |> assign(
        page_title:
          "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Classes")} > #{class.name}",
        class: class,
        server_group: server_group,
        server_ids: {server_ids, server_ids_reducer},
        students: []
      )
      |> load_students()
      |> ok()
    else
      {:error, not_found} when not_found in [:class_not_found, :server_group_not_found] ->
        socket
        |> put_notification(Message.new(:error, gettext("Class not found")))
        |> push_navigate(to: ~p"/admin/classes")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl LiveView
  def handle_info(
        {:class_updated, %Class{id: id} = updated_class},
        %Socket{
          assigns: %{
            class: %Class{id: id, version: current_version} = class,
            server_group: %ServerGroup{id: id, version: current_version} = server_group
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          class: Class.refresh!(class, updated_class),
          server_group: ServerGroup.refresh!(server_group, updated_class)
        )
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_deleted, %Class{id: id}},
        %Socket{
          assigns: %{class: %Class{id: id} = class}
        } = socket
      ),
      do:
        socket
        |> put_notification(
          Message.new(:success, gettext("Deleted class {class}", class: class.name))
        )
        |> push_navigate(to: ~p"/admin/classes")
        |> noreply()

  @impl LiveView
  def handle_info(
        {student_event, %Student{class_id: id}},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      )
      when student_event in [:student_created, :student_updated, :student_deleted],
      do: socket |> load_students() |> noreply()

  @impl LiveView
  def handle_info(
        {:students_imported, %Class{id: id}, _students},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl LiveView
  def handle_info(
        {:preregistered_user_updated, %{group_id: id}},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl LiveView
  def handle_info(
        {server_event, _server} = event,
        %Socket{assigns: %{server_ids: {server_ids, reducer}}} = socket
      )
      when server_event in [:server_created, :server_updated, :server_deleted] do
    new_server_ids = reducer.(server_ids, event)

    socket
    |> assign(:server_ids, {new_server_ids, reducer})
    |> noreply()
  end

  defp load_students(%Socket{assigns: %{auth: auth, class: class}} = socket),
    do: assign(socket, students: Course.list_students(auth, class))
end
