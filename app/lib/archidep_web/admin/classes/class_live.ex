defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.AdminComponents
  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Helpers.StudentHelpers, only: [student_not_in_class_tooltip: 1]
  import ArchiDepWeb.Servers.ServerComponents, only: [expected_server_properties: 1]
  alias ArchiDep.Accounts
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive
  alias ArchiDepWeb.Servers.EditServerGroupExpectedPropertiesDialogLive

  @spec server_group_member_for(list(ServerGroupMember.t()), Student.t()) ::
          ServerGroupMember.t() | nil
  def server_group_member_for(members, %Student{id: id}),
    do: Enum.find(members, &match?(%ServerGroupMember{id: ^id}, &1))

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    [class_result, server_group_result] =
      Task.await_many([
        Task.async(fn -> Course.fetch_class(auth, id) end),
        Task.async(fn -> Servers.fetch_server_group(auth, id) end)
      ])

    # TODO: keep servers count up to date in real time
    with {:ok, class} <- class_result,
         {:ok, server_group} <- server_group_result do
      {server_ids, server_ids_reducer} =
        if connected?(socket) do
          set_process_label(__MODULE__, auth, class)
          :ok = Course.PubSub.subscribe_class(id)
          :ok = Course.PubSub.subscribe_class_students(id)
          :ok = Accounts.PubSub.subscribe_user_group_preregistered_users(id)
          :ok = Servers.PubSub.subscribe_server_group(id)
          :ok = Servers.PubSub.subscribe_server_group_members(id)
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
        students: [],
        server_group_members: []
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

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
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

  @impl true
  def handle_info(
        {:server_group_updated, %{id: id} = updated_group},
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
          class: Class.refresh!(class, updated_group),
          server_group: ServerGroup.refresh!(server_group, updated_group)
        )
        |> noreply()

  @impl true
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

  @impl true
  def handle_info(
        {student_event, %Student{class_id: id}},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      )
      when student_event in [:student_created, :student_updated, :student_deleted],
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:students_imported, %Class{id: id}, _students},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:server_group_member_updated, %ServerGroupMember{group_id: id}},
        %Socket{assigns: %{class: %Class{id: id}}} = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:preregistered_user_updated, %{group_id: id}},
        %Socket{
          assigns: %{class: %Class{id: id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
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

  defp load_students(
         %Socket{assigns: %{auth: auth, class: class, students: old_students}} = socket
       ) do
    [current_students, {:ok, server_group_members}] =
      Task.await_many([
        Task.async(fn -> Course.list_students(auth, class) end),
        Task.async(fn -> Servers.list_server_group_members(auth, class.id) end)
      ])

    if connected?(socket) do
      current_student_ids = MapSet.new(current_students, & &1.id)

      old_student_ids = MapSet.new(old_students, & &1.id)
      gone_student_ids = MapSet.difference(old_student_ids, current_student_ids)

      # Unsubscribe from events concerning students that are no longer in the
      # class
      for gone_student_id <- gone_student_ids do
        :ok = Course.PubSub.unsubscribe_student(gone_student_id)
      end

      new_student_ids = MapSet.difference(current_student_ids, old_student_ids)

      # Subscribe to events concerning new students in the class
      for new_student_id <- new_student_ids do
        :ok = Course.PubSub.subscribe_student(new_student_id)
      end
    end

    assign(socket, students: current_students, server_group_members: server_group_members)
  end
end
