defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.I18nHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.PubSub
  alias ArchiDep.Students.Schemas.Class
  alias ArchiDep.Students.Schemas.Student
  alias ArchiDepWeb.Admin.Classes.DeleteClassDialogLive
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.ImportStudentsDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive

  @spec expected_cpu(Class.t()) :: String.t()
  def expected_cpu(class) do
    [
      {"CPU", class.expected_server_cpus},
      {"cores", class.expected_server_cores},
      {"vCPU", class.expected_server_vcpus}
    ]
    |> Enum.filter(fn {_, value} -> value != nil end)
    |> Enum.map(fn {label, value} -> "#{value} #{pluralize(value, label)}" end)
    |> Enum.join(", ")
  end

  @spec expected_memory(Class.t()) :: String.t()
  def expected_memory(class) do
    [
      {"RAM", class.expected_server_memory},
      {"Swap", class.expected_server_swap}
    ]
    |> Enum.filter(fn {_, value} -> value != nil end)
    |> Enum.map(fn {label, value} -> "#{value} MB #{label}" end)
    |> Enum.join(", ")
  end

  @spec expected_os(Class.t()) :: String.t()
  def expected_os(class) do
    system_and_arch =
      [
        class.expected_server_system,
        class.expected_server_architecture
      ]
      |> Enum.filter(&(&1 != nil))
      |> Enum.join(" ")

    os_family =
      case class.expected_server_os_family do
        nil -> nil
        os_family -> "#{os_family} family"
      end

    [system_and_arch, os_family]
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(", ")
  end

  @spec expected_distribution(Class.t()) :: String.t()
  def expected_distribution(class) do
    [
      class.expected_server_distribution,
      class.expected_server_distribution_version,
      class.expected_server_distribution_release
    ]
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(" ")
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    with {:ok, class} <- Students.fetch_class(auth, id) do
      if connected?(socket) do
        set_process_label(__MODULE__, auth, class)
        :ok = PubSub.subscribe_class(class.id)
        :ok = PubSub.subscribe_class_students(class.id)
      end

      socket
      |> assign(
        page_title: "ArchiDep > Admin > Classes > #{class.name}",
        class: class,
        students: []
      )
      |> load_students()
      |> ok()
    else
      {:error, :class_not_found} ->
        socket
        |> put_flash(:error, "Class not found")
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
          assigns: %{class: %Class{id: class_id}}
        } = socket
      ),
      do: socket |> push_navigate(to: ~p"/admin/classes") |> noreply()

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
