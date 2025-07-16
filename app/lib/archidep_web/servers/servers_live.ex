defmodule ArchiDepWeb.Servers.ServersLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl true
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [owner, servers, groups] =
      Task.await_many([
        Task.async(fn -> ServerOwner.fetch_authenticated(auth) end),
        Task.async(fn -> Servers.list_my_servers(auth) end),
        if(has_role?(auth, :root),
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

        {:ok, pid} = ServerTracker.start_link(servers)
        pid
      else
        nil
      end

    socket
    |> assign(
      page_title: "#{gettext("ArchiDep")} > #{gettext("Servers")}",
      servers: servers,
      server_state_map: ServerTracker.server_state_map(servers),
      server_tracker: tracker,
      owner: owner,
      groups: groups
    )
    |> ok()
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("retry_connecting", %{"server_id" => server_id}, socket)
      when is_binary(server_id) do
    :ok = Servers.retry_connecting(socket.assigns.auth, server_id)
    noreply(socket)
  end

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

  @impl true
  def handle_info(
        {:server_created, %Server{owner_id: owner_id} = created_server},
        %{
          assigns: %{
            owner: %ServerOwner{id: owner_id},
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    :ok = PubSub.subscribe_server(created_server.id)

    socket
    |> assign(
      servers: sort_servers([created_server | servers]),
      server_state_map:
        ServerTracker.update_server_state_map(
          server_state_map,
          ServerTracker.track(tracker, created_server)
        )
    )
    |> noreply()
  end

  def handle_info({:server_created, _unrelated_server}, socket) do
    noreply(socket)
  end

  @impl true
  def handle_info(
        {:server_updated, %Server{id: server_id} = server},
        %{assigns: %{servers: servers}} = socket
      ) do
    socket
    |> assign(
      servers:
        servers
        |> Enum.map(fn
          %Server{id: ^server_id} ->
            server

          other_server ->
            other_server
        end)
        |> sort_servers()
    )
    |> noreply()
  end

  @impl true
  def handle_info(
        {:server_deleted, %Server{id: server_id} = server},
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
      server_state_map:
        ServerTracker.update_server_state_map(
          server_state_map,
          ServerTracker.untrack(tracker, server)
        )
    )
    |> noreply()
  end

  defp sort_servers(servers),
    do: Enum.sort_by(servers, &{&1.name, &1.username, :inet.ntoa(&1.ip_address.address)})
end
