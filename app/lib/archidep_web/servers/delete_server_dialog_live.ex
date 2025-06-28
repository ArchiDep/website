defmodule ArchiDepWeb.Servers.DeleteServerDialogLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState

  @base_id "delete-server-dialog"

  @spec id(Server.t()) :: String.t()
  def id(server), do: "#{@base_id}-#{server.id}"

  @spec close(Server.t()) :: js
  def close(server), do: server |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        server: assigns.server,
        state: assigns.state
      )
      |> ok()

  @impl LiveComponent

  def handle_event("closed", _params, socket), do: {:noreply, socket}

  def handle_event("delete", _params, socket) do
    auth = socket.assigns.auth
    server = socket.assigns.server

    with :ok <- Servers.delete_server(auth, server.id) do
      socket |> put_flash(:info, "Server deleted") |> noreply()
    else
      {:error, :server_busy} ->
        noreply(socket)
    end
  end
end
