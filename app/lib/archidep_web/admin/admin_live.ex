defmodule ArchiDepWeb.Admin.AdminLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassCreated
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.Events.ClassUpdated
  alias ArchiDep.CourseSite.Archives
  alias ArchiDep.CourseSite.Archives.Completeness
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
  alias ArchiDepWeb.LiveRefresh
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

    # One self-managing tracker per class watches that group's servers on its
    # own (it subscribes to the group topic and tracks/untracks autonomously),
    # so the page does not orchestrate tracking; it only keeps the grouped list
    # and the aggregate state map fed by the trackers.
    server_trackers =
      if connected?(socket) do
        Map.new(active_classes, fn class ->
          {class.id, start_group_tracker(auth, servers_by_class_id, class.id)}
        end)
      else
        %{}
      end

    socket
    |> assign(
      active_classes: active_classes,
      page_title: gettext("Admin"),
      servers_by_class_id: servers_by_class_id,
      server_state_map: ServerTrackerClient.server_state_map(all_servers),
      server_trackers: server_trackers,
      ssh_public_key: SSH.ssh_public_key(),
      # Whether this deployment holds the finished editions of the course it is
      # supposed to serve. Worked out here rather than kept anywhere: it is a
      # handful of file lookups over compiled facts, and reading it on mount is
      # what makes it the state of the deployment now rather than at its last
      # boot.
      archives: Archives.completeness(),
      ansible: ansible
    )
    |> attach_server_state_refresh()
    |> ok()
  end

  @impl LiveView
  def handle_info(
        {:class_created, %ClassCreated{id: class_id}, _reference},
        %Socket{
          assigns: %{
            auth: auth,
            active_classes: active_classes,
            servers_by_class_id: servers_by_class_id,
            server_trackers: server_trackers
          }
        } = socket
      ) do
    # The created broadcast carries only the curated event, so fetch the full
    # read-view on first sighting through the authorized Course boundary, as the
    # server-created handler does for servers.
    with {:ok, %ClassView{} = created_view} <- Course.fetch_class(auth, class_id),
         true <- ClassView.active?(created_view, Clock.now()) do
      new_servers_by_class_id = Map.put_new(servers_by_class_id, created_view.id, [])

      socket
      |> assign(
        active_classes: active_classes |> add_class(created_view) |> sort_classes(),
        servers_by_class_id: new_servers_by_class_id,
        server_trackers:
          watch_group(auth, new_servers_by_class_id, server_trackers, created_view.id)
      )
      |> noreply()
    else
      _not_added -> noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(
        {:class_updated, event, reference},
        %Socket{
          assigns: %{
            auth: auth,
            active_classes: active_classes,
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_trackers: server_trackers
          }
        } = socket
      ) do
    id = class_updated_id(event)

    case resolve_updated_class(active_classes, id, event, reference, auth) do
      {:ok, updated_class} ->
        if ClassView.active?(updated_class, Clock.now()) do
          new_servers_by_class_id = Map.put_new(servers_by_class_id, updated_class.id, [])

          socket
          |> assign(
            active_classes:
              sort_classes(
                if(Enum.any?(active_classes, &(&1.id == id)),
                  do: update_class(active_classes, updated_class),
                  else: add_class(active_classes, updated_class)
                )
              ),
            servers_by_class_id: new_servers_by_class_id,
            server_trackers:
              watch_group(auth, new_servers_by_class_id, server_trackers, updated_class.id)
          )
          |> noreply()
        else
          socket
          |> assign(
            active_classes: active_classes |> remove_class(updated_class) |> sort_classes(),
            servers_by_class_id: Map.delete(servers_by_class_id, updated_class.id),
            server_trackers: unwatch_group(server_trackers, updated_class.id),
            server_state_map:
              drop_group_states(server_state_map, servers_by_class_id, updated_class.id)
          )
          |> noreply()
        end

      :ignore ->
        noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(
        {:class_deleted, %ClassDeleted{} = deleted_class, _reference},
        %Socket{
          assigns: %{
            active_classes: active_classes,
            servers_by_class_id: servers_by_class_id,
            server_state_map: server_state_map,
            server_trackers: server_trackers
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_classes: remove_class(active_classes, deleted_class),
          servers_by_class_id: Map.delete(servers_by_class_id, deleted_class.id),
          server_trackers: unwatch_group(server_trackers, deleted_class.id),
          server_state_map:
            drop_group_states(server_state_map, servers_by_class_id, deleted_class.id)
        )
        |> noreply()

  @impl LiveView
  def handle_info(
        {:server_created, %ServerCreated{group: %{id: group_id}} = event, _reference},
        %{assigns: %{auth: auth, servers_by_class_id: servers_by_class_id}} = socket
      ) do
    socket
    |> assign(
      servers_by_class_id: add_created_server(auth, servers_by_class_id, group_id, event.id)
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
        %{assigns: %{servers_by_class_id: servers_by_class_id}} = socket
      ) do
    # The group's own tracker untracks the deleted server on its own and pushes
    # the resulting absent state, so the page only drops it from the list here.
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
        end
    )
    |> noreply()
  end

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

  # The `:class_updated` broadcast carries either of the two class-update domain
  # events; both identify the class whose row must be reconciled.
  defp class_updated_id(%ClassUpdated{id: id}), do: id
  defp class_updated_id(%ClassExpectedServerPropertiesUpdated{class: %{id: id}}), do: id

  # A class already shown is reconciled in memory from the broadcast event; one
  # that is not (an inactive class becoming active) is fetched, since the event
  # alone cannot rebuild a full class to add to the list.
  defp resolve_updated_class(active_classes, id, event, reference, auth) do
    case Enum.find(active_classes, &(&1.id == id)) do
      %ClassView{} = cached ->
        {:ok, ClassView.refresh!(cached, event, reference)}

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

  defp update_class(classes, %ClassView{id: id} = class) do
    Enum.map(classes, fn
      %ClassView{id: ^id} ->
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

  defp add_created_server(auth, servers_by_class_id, group_id, server_id) do
    servers = Map.get(servers_by_class_id, group_id)

    cond do
      servers == nil ->
        servers_by_class_id

      Enum.any?(servers, &(&1.id == server_id)) ->
        servers_by_class_id

      true ->
        case Servers.fetch_server(auth, server_id) do
          {:ok, created_server} ->
            Map.put(servers_by_class_id, group_id, sort_servers([created_server | servers]))

          {:error, _reason} ->
            servers_by_class_id
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
         %{assigns: %{servers_by_class_id: servers_by_class_id}} = socket,
         %ServerView{} = updated_server
       ) do
    new_servers_by_class_id =
      case Map.get(servers_by_class_id, updated_server.group_id) do
        nil ->
          servers_by_class_id

        servers ->
          Map.put(
            servers_by_class_id,
            updated_server.group_id,
            place_server(servers, updated_server)
          )
      end

    socket
    |> assign(servers_by_class_id: new_servers_by_class_id)
    |> noreply()
  end

  # Replace the matching server in the group's list, or add it (sorted) when it
  # is appearing there for the first time (e.g. a server reassigned to it).
  defp place_server(servers, %ServerView{id: server_id} = updated_server) do
    if Enum.any?(servers, &(&1.id == server_id)) do
      Enum.map(servers, fn
        %ServerView{id: ^server_id} -> updated_server
        other_server -> other_server
      end)
    else
      sort_servers([updated_server | servers])
    end
  end

  defp start_group_tracker(auth, servers_by_class_id, class_id) do
    {:ok, pid} =
      ServerTrackerClient.start_link(
        auth,
        Map.get(servers_by_class_id, class_id, []),
        {:group, class_id}
      )

    pid
  end

  defp watch_group(auth, servers_by_class_id, server_trackers, class_id) do
    if Map.has_key?(server_trackers, class_id) do
      server_trackers
    else
      Map.put(server_trackers, class_id, start_group_tracker(auth, servers_by_class_id, class_id))
    end
  end

  defp unwatch_group(server_trackers, class_id) do
    case Map.pop(server_trackers, class_id) do
      {nil, server_trackers} ->
        server_trackers

      {tracker, remaining} ->
        if Process.alive?(tracker), do: GenServer.stop(tracker)
        remaining
    end
  end

  # A stopped group tracker no longer refreshes its servers' real-time state, so
  # drop those now-orphaned entries from the aggregate map that feeds the
  # connected-server count.
  defp drop_group_states(server_state_map, servers_by_class_id, class_id) do
    ids = servers_by_class_id |> Map.get(class_id, []) |> Enum.map(& &1.id)
    Map.drop(server_state_map, ids)
  end

  defp attach_server_state_refresh(socket) do
    if connected?(socket) do
      LiveRefresh.attach(socket, :server_state_map, &Servers.refresh_server_state_map/2)
    else
      socket
    end
  end

  defp sort_classes(classes),
    do: Enum.sort_by(classes, &{!&1.active, &1.end_date, &1.created_at, &1.name}, :desc)

  defp sort_servers(servers), do: Enum.sort_by(servers, & &1.created_at, :asc)
end
