defmodule ArchiDepWeb.Admin.AdminLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.ClassHelpers, only: [class_updated_id: 1]
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.PubSub.Scope
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.SSH
  alias ArchiDep.TrackerClient
  alias ArchiDepWeb.Admin.AdminClassServersLive
  alias Ecto.UUID
  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  @spec real_time_states_for(list(ServerView.t()), %{
          optional(UUID.t()) => ServerRealTimeState.t() | nil
        }) ::
          %{optional(UUID.t()) => ServerRealTimeState.t() | nil}
  def real_time_states_for(class_servers, server_state_map),
    do:
      class_servers
      |> Enum.map(fn server ->
        {server.id, Map.get(server_state_map, server.id)}
      end)
      |> Enum.into(%{})

  @spec count_connected(%{optional(UUID.t()) => ServerRealTimeState.t() | nil}) ::
          non_neg_integer()
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

    ansible =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)

        :ok = Course.PubSub.subscribe_classes()
        :ok = PubSub.subscribe(@pubsub, "tracker:" <> Scope.global_topic("ansible-queue"))

        for class <- active_classes do
          :ok = Servers.PubSub.subscribe_server_group_servers(class.id)
        end

        "ansible-queue"
        |> Scope.global_topic()
        |> TrackerClient.list()
        |> Enum.reduce(%{demand: 0, pending: 0, ongoing: MapSet.new()}, fn
          {"queue:" <> _queue, %{demand: demand, pending: pending}}, acc ->
            acc
            |> Map.put(:demand, demand)
            |> Map.put(:pending, pending)

          {key, _meta}, %{ongoing: ongoing} = acc ->
            Map.put(acc, :ongoing, MapSet.put(ongoing, key))
        end)
      else
        %{
          demand: 0,
          pending: 0,
          ongoing: MapSet.new()
        }
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
        {:ok, pid} = ServerTrackerClient.start_link(all_servers)
        pid
      end

    socket
    |> assign(
      active_classes: active_classes,
      page_title: gettext("Admin"),
      servers_by_class_id: servers_by_class_id,
      server_state_map: ServerTrackerClient.server_state_map(all_servers),
      server_tracker: tracker,
      ssh_public_key: SSH.ssh_public_key(),
      ansible: ansible
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
    if Class.active?(created_class, Clock.now()) do
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
        {:class_updated, event, reference},
        %Socket{
          assigns: %{
            auth: auth,
            active_classes: active_classes,
            servers_by_class_id: servers_by_class_id
          }
        } = socket
      ) do
    id = class_updated_id(event)

    case resolve_updated_class(active_classes, id, event, reference, auth) do
      {:ok, updated_class} ->
        if Class.active?(updated_class, Clock.now()) do
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

      :ignore ->
        noreply(socket)
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
        {:server_created, %ServerCreated{group: %{id: group_id}} = event, _reference},
        %{
          assigns: %{
            auth: auth,
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    {new_servers_by_class_id, new_server_state_map} =
      add_created_server(auth, tracker, servers_by_class_id, server_state_map, group_id, event.id)

    socket
    |> assign(
      servers_by_class_id: new_servers_by_class_id,
      server_state_map: new_server_state_map
    )
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_updated, event, reference},
        %{assigns: %{auth: auth, servers_by_class_id: servers_by_class_id}} = socket
      ) do
    case find_cached_server(servers_by_class_id, event.id) do
      %ServerView{} = cached ->
        apply_server_updated(socket, ServerView.refresh!(cached, event, reference))

      nil ->
        resolve_and_apply_server_updated(socket, auth, event.id)
    end
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, %ServerDeleted{group: %{id: group_id}, id: server_id}, _reference},
        %{
          assigns: %{
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
    new_server_state_map =
      case find_cached_server(servers_by_class_id, server_id) do
        nil ->
          server_state_map

        server ->
          ServerTrackerClient.update_server_state_map(
            server_state_map,
            ServerTrackerClient.untrack(tracker, server)
          )
      end

    socket
    |> assign(
      servers_by_class_id:
        case Map.get(servers_by_class_id, group_id) do
          nil ->
            servers_by_class_id

          servers ->
            Map.put(
              servers_by_class_id,
              group_id,
              Enum.reject(servers, &(&1.id == server_id))
            )
        end,
      server_state_map: new_server_state_map
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
          server_state_map: ServerTrackerClient.update_server_state_map(server_state_map, update)
        )
        |> noreply()

  @impl LiveView

  def handle_info(
        {action, "queue:" <> _queue, %{pending: pending}},
        %Socket{assigns: %{ansible: ansible}} = socket
      )
      when action in [:join, :update],
      do:
        socket
        |> assign(ansible: Map.put(ansible, :pending, pending))
        |> noreply()

  def handle_info(
        {action, key, %{}},
        %Socket{assigns: %{ansible: %{ongoing: ongoing} = ansible}} = socket
      )
      when action in [:join, :update],
      do:
        socket
        |> assign(ansible: Map.put(ansible, :ongoing, MapSet.put(ongoing, key)))
        |> noreply()

  @impl LiveView

  def handle_info(
        {:leave, "queue:" <> _queue, %{}},
        %Socket{assigns: %{ansible: ansible}} = socket
      ),
      do:
        socket
        |> assign(ansible: Map.put(ansible, :pending, 0))
        |> noreply()

  def handle_info(
        {:leave, key, %{}},
        %Socket{assigns: %{ansible: %{ongoing: ongoing} = ansible}} = socket
      ),
      do:
        socket
        |> assign(ansible: Map.put(ansible, :ongoing, MapSet.delete(ongoing, key)))
        |> noreply()

  # A class already shown is reconciled in memory from the broadcast event; one
  # that is not (an inactive class becoming active) is fetched, since the event
  # alone cannot rebuild a full class to add to the list.
  defp resolve_updated_class(active_classes, id, event, reference, auth) do
    case Enum.find(active_classes, &(&1.id == id)) do
      %Class{} = cached ->
        {:ok, Class.refresh!(cached, event, reference)}

      nil ->
        case Course.fetch_class(auth, id) do
          {:ok, class} -> {:ok, class}
          {:error, _reason} -> :ignore
        end
    end
  end

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
      %Class{id: ^id} ->
        class

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

  defp add_created_server(
         auth,
         tracker,
         servers_by_class_id,
         server_state_map,
         group_id,
         server_id
       ) do
    servers = Map.get(servers_by_class_id, group_id)

    cond do
      servers == nil ->
        {servers_by_class_id, server_state_map}

      Enum.any?(servers, &(&1.id == server_id)) ->
        {servers_by_class_id, server_state_map}

      true ->
        case Servers.fetch_server(auth, server_id) do
          {:ok, created_server} ->
            {
              Map.put(servers_by_class_id, group_id, sort_servers([created_server | servers])),
              ServerTrackerClient.update_server_state_map(
                server_state_map,
                ServerTrackerClient.track(tracker, created_server)
              )
            }

          {:error, _reason} ->
            {servers_by_class_id, server_state_map}
        end
    end
  end

  defp find_cached_server(servers_by_class_id, server_id),
    do:
      servers_by_class_id
      |> Map.values()
      |> Enum.find_value(fn servers -> Enum.find(servers, &(&1.id == server_id)) end)

  defp resolve_and_apply_server_updated(socket, auth, server_id) do
    case Servers.fetch_server(auth, server_id) do
      {:ok, updated_server} -> apply_server_updated(socket, updated_server)
      {:error, _reason} -> noreply(socket)
    end
  end

  defp apply_server_updated(
         %{
           assigns: %{
             servers_by_class_id: servers_by_class_id,
             server_state_map: server_state_map,
             server_tracker: tracker
           }
         } = socket,
         %ServerView{id: server_id} = updated_server
       ) do
    {new_servers_by_class_id, new_server_state_map} =
      case Map.get(servers_by_class_id, updated_server.group_id) do
        nil ->
          {servers_by_class_id, server_state_map}

        servers ->
          if Enum.any?(servers, &(&1.id == server_id)) do
            {
              Map.put(
                servers_by_class_id,
                updated_server.group_id,
                Enum.map(servers, fn
                  %ServerView{id: ^server_id} -> updated_server
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
              ServerTrackerClient.update_server_state_map(
                server_state_map,
                ServerTrackerClient.track(tracker, updated_server)
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

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)

  defp sort_servers(servers), do: Enum.sort_by(servers, & &1.created_at, :asc)
end
