defmodule ArchiDepWeb.Servers.ServerLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager
  alias ArchiDep.Servers.ServerTracker
  alias ArchiDepWeb.Servers.EditServerDialogLive

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    with {:ok, server} <- Servers.fetch_server(auth, id) do
      if connected?(socket) do
        set_process_label(__MODULE__, auth, server)
        {:ok, _pid} = ServerTracker.start_link(server)
      end

      socket
      |> assign(
        page_title: "ArchiDep > Servers > #{Server.name_or_default(server)}",
        server: server,
        state: ServerTracker.get_current_server_state(server)
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

  @impl true
  def handle_params(_params, _url, socket), do: noreply(socket)

  @impl true
  def handle_event("retry_connecting", %{"server_id" => server_id}, socket)
      when is_binary(server_id) do
    :ok = ServerManager.retry_connecting(socket.assigns.server)
    noreply(socket)
  end

  @impl true
  def handle_info(
        {:server_state, server_id, new_server_state},
        %Socket{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do:
        socket
        |> assign(state: new_server_state)
        |> noreply()
end
