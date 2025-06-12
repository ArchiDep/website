defmodule ArchiDepWeb.Servers.ServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    servers = Servers.list_my_servers(socket.assigns.auth)

    socket
    |> assign(
      page_title: "ArchiDep > Servers",
      servers: servers
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
