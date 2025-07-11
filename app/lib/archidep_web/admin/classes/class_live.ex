defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents, only: [expected_server_properties: 1]
  alias ArchiDep.Servers
  alias ArchiDep.Students
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive
  alias ArchiDepWeb.Servers.EditServerGroupExpectedPropertiesDialogLive

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    [class_result, server_group_result] =
      Task.await_many([
        Task.async(fn -> Students.fetch_class(auth, id) end),
        Task.async(fn -> Servers.fetch_server_group(auth, id) end)
      ])

    # TODO: keep servers count up to date in real time
    with {:ok, class} <- class_result,
         {:ok, server_group} <- server_group_result do
      if connected?(socket) do
        set_process_label(__MODULE__, auth, class)
        :ok = PubSub.subscribe_class(class.id)
        :ok = PubSub.subscribe_class_students(class.id)
      end

      socket
      |> assign(
        page_title:
          "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Classes")} > #{class.name}",
        class: class,
        server_group: server_group,
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

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:class_updated, %Class{id: class_id} = updated_class},
        %Socket{
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> assign(class: updated_class) |> noreply()

  @impl true
  def handle_info(
        {:class_deleted, %Class{id: class_id}},
        %Socket{
          assigns: %{class: %Class{id: class_id} = class}
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
        {:student_created, %Student{class_id: class_id}},
        %Socket{
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:students_imported, %Class{id: class_id}, _students},
        %Socket{
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:student_updated, %Student{class_id: class_id}},
        %Socket{
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  @impl true
  def handle_info(
        {:student_deleted, %Student{class_id: class_id}},
        %Socket{
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> load_students() |> noreply()

  defp load_students(
         %Socket{assigns: %{auth: auth, class: class, students: old_students}} = socket
       ) do
    current_students = Students.list_students(auth, class)

    if connected?(socket) do
      current_student_ids = MapSet.new(current_students, & &1.id)

      old_student_ids = MapSet.new(old_students, & &1.id)
      gone_student_ids = MapSet.difference(old_student_ids, current_student_ids)

      # Unsubscribe from events concerning students that are no longer in the
      # class
      for gone_student_id <- gone_student_ids do
        :ok = PubSub.unsubscribe_student(gone_student_id)
      end

      new_student_ids = MapSet.difference(current_student_ids, old_student_ids)

      # Subscribe to events concerning new students in the class
      for new_student_id <- new_student_ids do
        :ok = PubSub.subscribe_student(new_student_id)
      end
    end

    assign(socket, :students, current_students)
  end
end
