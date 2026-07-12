defmodule ArchiDepWeb.Dashboard.MyServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
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

        for server <- servers do
          # TODO: add watch_my_servers in context
          :ok = PubSub.subscribe_server(server.id)
        end

        :ok = PubSub.subscribe_server_created()

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
    # Subscribe before fetching so an update broadcast in the window between
    # reading the server and starting to listen is queued rather than lost.
    :ok = PubSub.subscribe_server(event.id)

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
        :ok = PubSub.unsubscribe_server(event.id)
        noreply(socket)
    end
  end

  def handle_info({:server_created, _event, _reference}, socket) do
    noreply(socket)
  end

  @impl LiveView
  def handle_info(
        {:server_updated, event, reference},
        %{assigns: %{servers: servers}} = socket
      ) do
    server_id = event.id

    case Enum.find(servers, &(&1.id == server_id)) do
      nil ->
        noreply(socket)

      cached_server ->
        server = ServerView.refresh!(cached_server, event, reference)

        socket
        |> assign(
          servers:
            servers
            |> Enum.map(fn
              %ServerView{id: ^server_id} ->
                server

              other_server ->
                other_server
            end)
            |> sort_servers()
        )
        |> noreply()
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
    :ok = PubSub.unsubscribe_server(server_id)

    socket
    |> assign(
      servers: Enum.reject(servers, fn current_server -> current_server.id == server_id end),
      server_state_map: untrack_server(tracker, server_state_map, servers, server_id)
    )
    |> noreply()
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
