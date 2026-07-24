defmodule ArchiDepWeb.Admin.Classes.ClassesLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.DateFormatHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDepWeb.Admin.Classes.NewClassDialogLive
  alias ArchiDepWeb.LiveRefresh

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    classes = Course.list_classes(auth)

    socket
    |> assign(
      page_title: "#{gettext("Classes")} · #{gettext("Admin")}",
      classes: classes
    )
    |> track_classes(auth)
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)

  # On connected mount, keep the classes list current through the Course
  # boundary. The refresher owns create, update, delete and ordering, so this
  # page names no topics or events.
  defp track_classes(socket, auth) do
    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = Course.subscribe_classes()
      LiveRefresh.attach(socket, :classes, &Course.refresh_classes(auth, &1, &2))
    else
      socket
    end
  end
end
