defmodule ArchiDepWeb.Admin.Classes.ClassesLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Students
  alias ArchiDepWeb.Admin.Classes.NewClassDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth
    classes = Students.list_classes(auth)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

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
