defmodule ArchiDepWeb.Admin.Classes.ClassLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.EditClassDialogLive
  alias ArchiDepWeb.Admin.Classes.NewStudentDialogLive

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
