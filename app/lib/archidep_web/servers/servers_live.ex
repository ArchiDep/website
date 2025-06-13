defmodule ArchiDepWeb.Servers.ServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Students
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [servers, classes] =
      Task.await_many([
        Task.async(fn -> Servers.list_my_servers(auth) end),
        Task.async(fn -> Students.list_classes(auth) end)
      ])

    socket
    |> assign(
      page_title: "ArchiDep > Servers",
      servers: servers,
      classes: classes
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
