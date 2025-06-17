defmodule ArchiDepWeb.Servers.ServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.ServerTracker
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

    if connected?(socket) do
      {:ok, _pid} = ServerTracker.start_link(servers)
    end

    socket
    |> assign(
      page_title: "ArchiDep > Servers",
      servers: servers,
      server_state_map: ServerTracker.server_state_map(servers),
      classes: classes
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_info(
        {:server_state, _server_id, _new_server_state} = update,
        %{assigns: %{server_state_map: server_state_map}} = socket
      ),
      do:
        socket
        |> assign(
          server_state_map: ServerTracker.update_server_state_map(server_state_map, update)
        )
        |> noreply()
end
