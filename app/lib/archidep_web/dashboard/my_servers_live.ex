defmodule ArchiDepWeb.Dashboard.MyServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDepWeb.LiveRefresh
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [servers, groups] =
      Task.await_many([
        Task.async(fn -> Servers.list_my_servers(auth) end),
        if(root?(auth),
          do: Task.async(fn -> Servers.list_server_groups(auth) end),
          else: Task.completed(nil)
        )
      ])

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
      :ok = Servers.subscribe_my_servers(auth)
      {:ok, _tracker} = ServerTrackerClient.start_link(auth, servers, :all)
    end

    socket
    |> assign(
      servers: servers,
      server_state_map: ServerTrackerClient.server_state_map(servers),
      groups: groups
    )
    |> attach_refreshers()
    |> ok()
  end

  @impl LiveView
  def handle_event("retry_connecting", %{"server_id" => server_id}, socket)
      when is_binary(server_id) do
    :ok = Servers.retry_connecting(socket.assigns.auth, server_id)
    noreply(socket)
  end

  # On connected mount, keep both read-models current through the Servers
  # boundary: the list refresher owns creation, update, deletion and ordering,
  # and the state-map refresher folds the real-time states the self-managing
  # tracker pushes. The page therefore names no topics or events, and the
  # tracker starts and stops watching each server on its own.
  defp attach_refreshers(socket) do
    if connected?(socket) do
      auth = socket.assigns.auth

      socket
      |> LiveRefresh.attach(:servers, &Servers.refresh_my_servers(auth, &1, &2))
      |> LiveRefresh.attach(:server_state_map, &Servers.refresh_server_state_map/2)
    else
      socket
    end
  end
end
