defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.I18nHelpers
  alias ArchiDep.Students
  alias ArchiDep.Students.Schemas.Class
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

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    with {:ok, class} <- Students.fetch_class(socket.assigns.auth, id) do
      socket
      |> assign(
        page_title: "ArchiDep > Admin > Classes > #{class.name}",
        class: class,
        students: Students.list_students(socket.assigns.auth, class)
      )
      |> ok()
    else
      {:error, :class_not_found} ->
        socket
        |> put_flash(:error, "Class not found")
        |> push_navigate(to: ~p"/admin/classes")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
