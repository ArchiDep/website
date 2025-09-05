defmodule ArchiDepWeb.Admin.AdminLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDep.Servers.SSH
  alias ArchiDepWeb.Admin.AdminClassServersLive
  alias Ecto.UUID

  @spec real_time_states_for(list(Server.t()), %{optional(UUID.t()) => ServerRealTimeState.t()}) ::
          %{optional(UUID.t()) => ServerRealTimeState.t()}
  def real_time_states_for(class_servers, server_state_map),
    do:
      class_servers
      |> Enum.map(fn server ->
        {server.id, Map.get(server_state_map, server.id)}
      end)
      |> Enum.into(%{})

  @spec count_connected(%{optional(UUID.t()) => ServerRealTimeState.t()}) :: non_neg_integer()
  def count_connected(server_state_map),
    do:
      server_state_map
      |> Map.values()
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.connection_state)
      |> Enum.count(&ServerConnectionState.connected?/1)

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    active_classes = Course.list_active_classes(auth)

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      :ok = PubSub.subscribe_classes()

      for class <- active_classes do
        :ok = Servers.PubSub.subscribe_server_group_servers(class.id)
      end
    end

    servers_by_class_id =
      active_classes
      |> Enum.map(fn class ->
        Task.async(fn ->
          {:ok, servers} = Servers.list_all_servers_in_group(auth, class.id)
          {class.id, sort_servers(servers)}
        end)
      end)
      |> Task.await_many()
      |> Enum.into(%{})

    all_servers = servers_by_class_id |> Map.values() |> List.flatten()

    tracker =
      if connected?(socket) do
        {:ok, pid} = ServerTracker.start_link(all_servers)
        pid
      end

    socket
    |> assign(
      active_classes: active_classes,
      servers_by_class_id: servers_by_class_id,
      server_state_map: ServerTracker.server_state_map(all_servers),
      server_tracker: tracker,
      ssh_public_key: SSH.ssh_public_key()
    )
    |> ok()
  end

  @impl LiveView
  def handle_info(
        {:class_created, created_class},
        %Socket{
          assigns: %{active_classes: active_classes, servers_by_class_id: servers_by_class_id}
        } = socket
      ) do
    if Class.active?(created_class, DateTime.utc_now()) do
      socket
      |> assign(
        active_classes: active_classes |> add_class(created_class) |> sort_classes(),
        servers_by_class_id: Map.put_new(servers_by_class_id, created_class.id, [])
      )
      |> noreply()
    else
      noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(
        {:class_updated, %{id: id} = updated_class},
        %Socket{
          assigns: %{active_classes: active_classes, servers_by_class_id: servers_by_class_id}
        } = socket
      ) do
    if Class.active?(updated_class, DateTime.utc_now()) do
      socket
      |> assign(
        active_classes:
          sort_classes(
            if(Enum.any?(active_classes, &(&1.id == id)),
              do: update_class(active_classes, updated_class),
              else: add_class(active_classes, updated_class)
            )
          ),
        servers_by_class_id: Map.put_new(servers_by_class_id, updated_class.id, [])
      )
      |> noreply()
    else
      socket
      |> assign(
        active_classes: active_classes |> remove_class(updated_class) |> sort_classes(),
        servers_by_class_id: Map.delete(servers_by_class_id, updated_class.id)
      )
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:class_deleted, deleted_class},
        %Socket{
          assigns: %{active_classes: active_classes, servers_by_class_id: servers_by_class_id}
        } = socket
      ),
      do:
        socket
        |> assign(
          active_classes: remove_class(active_classes, deleted_class),
          servers_by_class_id: Map.delete(servers_by_class_id, deleted_class.id)
        )
        |> noreply()

  @impl LiveView
  def handle_info(
        {:server_created, created_server},
        %{
          assigns: %{
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    {new_servers_by_class_id, new_server_state_map} =
      case Map.get(servers_by_class_id, created_server.group_id) do
        nil ->
          {servers_by_class_id, server_state_map}

        servers ->
          if Enum.any?(servers, &(&1.id == created_server.id)) do
            {servers_by_class_id, server_state_map}
          else
            {
              Map.put(
                servers_by_class_id,
                created_server.group_id,
                sort_servers([created_server | servers])
              ),
              ServerTracker.update_server_state_map(
                server_state_map,
                ServerTracker.track(tracker, created_server)
              )
            }
          end
      end

    socket
    |> assign(
      servers_by_class_id: new_servers_by_class_id,
      server_state_map: new_server_state_map
    )
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_updated, updated_server},
        %{
          assigns: %{
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    server_id = updated_server.id

    {new_servers_by_class_id, new_server_state_map} =
      case Map.get(servers_by_class_id, updated_server.group_id) do
        nil ->
          {servers_by_class_id, server_state_map}

        servers ->
          if Enum.any?(servers, &(&1.id == updated_server.id)) do
            {
              Map.put(
                servers_by_class_id,
                updated_server.group_id,
                Enum.map(servers, fn
                  %Server{id: ^server_id} -> updated_server
                  other_server -> other_server
                end)
              ),
              server_state_map
            }
          else
            {
              Map.put(
                servers_by_class_id,
                updated_server.group_id,
                sort_servers([updated_server | servers])
              ),
              ServerTracker.update_server_state_map(
                server_state_map,
                ServerTracker.track(tracker, updated_server)
              )
            }
          end
      end

    socket
    |> assign(
      servers_by_class_id: new_servers_by_class_id,
      server_state_map: new_server_state_map
    )
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, deleted_server},
        %{
          assigns: %{
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    socket
    |> assign(
      servers_by_class_id:
        case Map.get(servers_by_class_id, deleted_server.group_id) do
          nil ->
            servers_by_class_id

          servers ->
            Map.put(
              servers_by_class_id,
              deleted_server.group_id,
              Enum.reject(servers, &(&1.id == deleted_server.id))
            )
        end,
      server_state_map:
        ServerTracker.update_server_state_map(
          server_state_map,
          ServerTracker.untrack(tracker, deleted_server)
        )
    )
    |> noreply()
  end

  @impl LiveView
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

  defp add_class(classes, class) do
    if Enum.any?(classes, &(&1.id == class.id)) do
      classes
    else
      :ok = Servers.PubSub.subscribe_server_group_servers(class.id)
      [class | classes]
    end
  end

  defp update_class(classes, %Class{id: id} = class) do
    Enum.map(classes, fn
      %Class{id: ^id} = c ->
        Class.refresh!(c, class)

      c ->
        c
    end)
  end

  defp remove_class(classes, class) do
    if Enum.any?(classes, &(&1.id == class.id)) do
      :ok = Servers.PubSub.unsubscribe_server_group_servers(class.id)
      Enum.reject(classes, fn c -> c.id == class.id end)
    else
      classes
    end
  end

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)

  defp sort_servers(servers), do: Enum.sort_by(servers, & &1.created_at, :asc)
end
