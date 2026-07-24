defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Components.CourseComponents
  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Servers
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassExpectedServerPropertiesDialogLive
  alias ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive
  alias ArchiDepWeb.LiveRefresh

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
      socket
      |> assign(
        page_title: "#{class.name} · #{gettext("Admin")}",
        class: class,
        server_ids: MapSet.new(),
        students: Course.list_students(auth, class)
      )
      |> track(auth, class, server_group)
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
        {:class_deleted, %Class{id: id}},
        %Socket{
          assigns: %{class: %ClassView{id: id} = class}
        } = socket
      ),
      do:
        socket
        |> put_notification(
          Message.new(:success, gettext("Deleted class {class}", class: class.name))
        )
        |> push_navigate(to: ~p"/admin/classes")
        |> noreply()

  # On connected mount, keep the class, its student list and the set of its
  # server IDs current through the Course and Servers boundaries; the page names
  # no topics or events. The server group is fetched only to authorize and scope
  # the server-id subscription; it is not rendered, so it is not tracked.
  defp track(socket, auth, class, server_group) do
    if connected?(socket) do
      set_process_label(__MODULE__, auth, class)
      :ok = Course.subscribe_class(class)
      :ok = Course.subscribe_class_students(class)
      {:ok, server_ids} = Servers.subscribe_server_group_servers(auth, server_group)

      socket
      |> LiveRefresh.attach(:class, &Course.refresh_class/2)
      |> LiveRefresh.attach(:students, &Course.refresh_class_students(auth, class, &1, &2))
      |> LiveRefresh.attach(:server_ids, &Servers.refresh_server_ids/2)
      |> assign(:server_ids, server_ids)
    else
      socket
    end
  end
end
