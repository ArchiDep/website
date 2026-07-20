defmodule ArchiDepWeb.Dashboard.MyServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
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

    tracker =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)
        :ok = Servers.subscribe_my_servers(auth)
        {:ok, pid} = ServerTrackerClient.start_link(servers)
        pid
      else
        nil
      end

    socket
    |> assign(
      servers: servers,
      server_state_map: ServerTrackerClient.server_state_map(servers),
      server_tracker: tracker,
      groups: groups
    )
    |> attach_my_servers_refresh()
    |> ok()
  end

  @impl LiveView
  def handle_event("retry_connecting", %{"server_id" => server_id}, socket)
      when is_binary(server_id) do
    :ok = Servers.retry_connecting(socket.assigns.auth, server_id)
    noreply(socket)
  end

  @impl LiveView
  def handle_info(
        {:server_state, _server_id, _new_server_state} = update,
        %{assigns: %{server_state_map: server_state_map}} = socket
      ),
      do:
        socket
        |> assign(
          server_state_map: ServerTrackerClient.update_server_state_map(server_state_map, update)
        )
        |> noreply()

  @impl LiveView
  def handle_info(
        {:server_created, %ServerCreated{owner: %{id: owner_id}} = event, _reference},
        %{
          assigns: %{
            auth: %Authentication{principal_id: owner_id} = auth,
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    case Servers.fetch_server(auth, event.id) do
      {:ok, created_server} ->
        socket
        |> assign(
          servers: sort_servers([created_server | servers]),
          server_state_map:
            ServerTrackerClient.update_server_state_map(
              server_state_map,
              ServerTrackerClient.track(tracker, created_server)
            )
        )
        |> noreply()

      {:error, _reason} ->
        noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, %ServerDeleted{id: server_id}, _reference},
        %{
          assigns: %{
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    socket
    |> assign(
      servers: Enum.reject(servers, fn current_server -> current_server.id == server_id end),
      server_state_map: untrack_server(tracker, server_state_map, servers, server_id)
    )
    |> noreply()
  end

  # On connected mount, keep the server list current through the Servers
  # boundary. The refresher reflects server-field updates and re-sorts the list;
  # creation and deletion fall through to this module's own handlers, which also
  # start and stop tracking each server's real-time state.
  defp attach_my_servers_refresh(socket) do
    if connected?(socket) do
      LiveRefresh.attach(socket, :servers, &Servers.refresh_my_servers/2)
    else
      socket
    end
  end

  defp untrack_server(tracker, server_state_map, servers, server_id) do
    case Enum.find(servers, &(&1.id == server_id)) do
      nil ->
        server_state_map

      server ->
        ServerTrackerClient.update_server_state_map(
          server_state_map,
          ServerTrackerClient.untrack(tracker, server)
        )
    end
  end

  defp sort_servers(servers),
    do: Enum.sort_by(servers, &{&1.name, &1.username, :inet.ntoa(&1.ip_address.address)})
end
