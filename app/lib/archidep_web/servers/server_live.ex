defmodule ArchiDepWeb.Servers.ServerLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDepWeb.Servers.EditServerDialogLive

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    with {:ok, server} <- Servers.fetch_server(socket.assigns.auth, id) do
      socket
      |> assign(
        page_title: "ArchiDep > Servers > #{Server.name_or_default(server)}",
        server: server
      )
      |> ok()
    else
      {:error, :server_not_found} ->
        socket
        |> put_flash(:error, "Server not found")
        |> push_navigate(to: ~p"/servers")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
