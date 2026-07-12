defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerHelpComponent
  import ArchiDepWeb.Servers.ServerRetryHandlers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Material
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias ArchiDepWeb.Course.ChangeUsernameDialogLive
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive
  alias ArchiDepWeb.Servers.EditServerDialogLive
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [student, servers, groups] =
      Task.await_many([
        Task.async(fn -> fetch_student(auth) end),
        Task.async(fn -> Servers.list_my_servers(auth) end),
        if(root?(auth),
          do: Task.async(fn -> Servers.list_server_groups(auth) end),
          else: Task.completed(nil)
        )
      ])

    ssh_exercise_vm_md5_host_key_fingerprints =
      with %Student{class: %Class{ssh_exercise_vm_md5_host_key_fingerprints: fingerprints}}
           when is_binary(fingerprints) <- student,
           {:ok, valid, _invalid} <- SSH.parse_ssh_host_key_fingerprints(fingerprints) do
        valid
      else
        _anything -> []
      end

    ssh_exercise_vm_sha256_host_key_fingerprints =
      with %Student{class: %Class{ssh_exercise_vm_sha256_host_key_fingerprints: fingerprints}}
           when is_binary(fingerprints) <- student,
           {:ok, valid, _invalid} <- SSH.parse_ssh_host_key_fingerprints(fingerprints) do
        valid
      else
        _anything -> []
      end

    active_servers = Enum.filter(servers, & &1.active)
    inactive_servers = Enum.reject(servers, & &1.active)

    tracker =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)

        if student != nil do
          :ok = Course.PubSub.subscribe_student(student.id)
          :ok = Course.PubSub.subscribe_class(student.class_id)
        end

        for server <- active_servers do
          # TODO: add watch_my_servers in context
          :ok = PubSub.subscribe_server(server.id)
        end

        :ok = PubSub.subscribe_server_owner_servers(auth.principal_id)

        {:ok, pid} = ServerTrackerClient.start_link(active_servers)
        pid
      else
        nil
      end

    socket
    |> assign(
      page_title: gettext("Dashboard"),
      now: Clock.now(),
      student: student,
      ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints: ssh_exercise_vm_sha256_host_key_fingerprints,
      servers: active_servers,
      inactive_servers: inactive_servers |> Enum.map(& &1.id) |> MapSet.new(),
      server_state_map: ServerTrackerClient.server_state_map(active_servers),
      server_tracker: tracker,
      groups: groups
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _uri, socket),
    do:
      socket
      |> assign(run_virtual_server_exercise_done: params["server"] == "ready")
      |> noreply()

  @impl LiveView
  def handle_event(
        "retry_connecting",
        %{"server_id" => server_id},
        socket
      ),
      do: handle_retry_connecting_event(socket, server_id)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "ansible-playbook", "playbook" => playbook},
        socket
      ),
      do: handle_retry_ansible_playbook_event(socket, server_id, playbook)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "check-open-ports"},
        socket
      ),
      do: handle_retry_checking_open_ports_event(socket, server_id)

  @impl LiveView
  def handle_info(
        {:student_updated, %{id: student_id} = event, reference},
        %Socket{assigns: %{student: %Student{id: student_id} = student}} = socket
      ),
      do:
        socket
        |> assign(student: Student.refresh!(student, event, reference))
        |> noreply()

  @impl LiveView
  def handle_info(
        {:student_deleted, %Student{id: student_id}},
        %Socket{
          assigns: %{
            student: %Student{id: student_id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil, server_group_member: nil)
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_updated, event, reference},
        %Socket{
          assigns: %{
            student: %Student{class: %Class{} = class} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: %Student{student | class: Class.refresh!(class, event, reference)})
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_deleted, %Class{id: id}},
        %Socket{
          assigns: %{
            student: %Student{class_id: id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil)
        |> noreply()

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
        {:server_created, %ServerCreated{owner: %{id: owner_id}, active: true} = event,
         _reference},
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

  def handle_info(
        {:server_created, %ServerCreated{} = event, _reference},
        %Socket{assigns: %{inactive_servers: inactive_servers}} = socket
      ) do
    socket
    |> assign(inactive_servers: MapSet.put(inactive_servers, event.id))
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_updated, event, reference},
        %{
          assigns: %{
            auth: %Authentication{principal_id: owner_id},
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker,
            inactive_servers: inactive_servers
          }
        } = socket
      ) do
    server_id = event.id

    updated_server =
      case Enum.find(servers, &(&1.id == server_id)) do
        %ServerView{} = cached -> ServerView.refresh!(cached, event, reference)
        nil -> resolve_fetched_server(socket.assigns.auth, server_id)
      end

    cond do
      updated_server != nil and updated_server.owner_id == owner_id and updated_server.active ->
        track_active_server(socket, updated_server, server_id)

      Enum.any?(servers, &(&1.id == server_id)) ->
        socket
        |> assign(
          servers: Enum.reject(servers, fn current_server -> current_server.id == server_id end),
          server_state_map:
            ServerTrackerClient.update_server_state_map(
              server_state_map,
              ServerTrackerClient.untrack(tracker, updated_server)
            ),
          inactive_servers: MapSet.put(inactive_servers, server_id)
        )
        |> noreply()

      true ->
        socket
        |> assign(inactive_servers: MapSet.put(inactive_servers, server_id))
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
            server_tracker: tracker,
            inactive_servers: inactive_servers
          }
        } = socket
      ) do
    socket
    |> assign(
      servers: Enum.reject(servers, fn current_server -> current_server.id == server_id end),
      server_state_map: untrack_server(tracker, server_state_map, servers, server_id),
      inactive_servers: MapSet.delete(inactive_servers, server_id)
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

  defp resolve_fetched_server(auth, server_id) do
    case Servers.fetch_server(auth, server_id) do
      {:ok, server} -> server
      {:error, _reason} -> nil
    end
  end

  defp track_active_server(
         %{
           assigns: %{
             servers: servers,
             server_state_map: server_state_map,
             server_tracker: tracker,
             inactive_servers: inactive_servers
           }
         } = socket,
         updated_server,
         server_id
       ) do
    [updated_servers, updated_server_state_map] =
      if Enum.any?(servers, &(&1.id == server_id)) do
        [
          Enum.map(servers, fn
            %ServerView{id: ^server_id} -> updated_server
            other_server -> other_server
          end),
          server_state_map
        ]
      else
        [
          [updated_server | servers],
          ServerTrackerClient.update_server_state_map(
            server_state_map,
            ServerTrackerClient.track(tracker, updated_server)
          )
        ]
      end

    socket
    |> assign(
      servers: sort_servers(updated_servers),
      server_state_map: updated_server_state_map,
      inactive_servers: MapSet.delete(inactive_servers, server_id)
    )
    |> noreply()
  end

  defp fetch_student(auth) do
    {:ok, student} =
      if root?(auth) do
        {:ok, nil}
      else
        Course.fetch_authenticated_student(auth)
      end

    student
  end

  defp sort_servers(servers),
    do: Enum.sort_by(servers, &{&1.name, &1.username, :inet.ntoa(&1.ip_address.address)})
end
