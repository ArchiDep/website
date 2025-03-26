defmodule ArchiDepWeb.Admin.Classes.ClassesLive do
  use ArchiDepWeb, :live_view

  alias ArchiDep.Students

  @impl LiveView
  def mount(_params, _session, socket) do
    classes = Students.list_classes(socket.assigns.auth)

    socket
    |> assign(
      page_title: "ArchiDep > Admin > Classes",
      classes: classes
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
