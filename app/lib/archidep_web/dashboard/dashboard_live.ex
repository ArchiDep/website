defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerHelpComponent
  import ArchiDepWeb.Servers.ServerRetryHandlers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
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

        {:ok, pid} = ServerTracker.start_link(active_servers)
        pid
      else
        nil
      end

    socket
    |> assign(
      page_title: gettext("Dashboard"),
      student: student,
      servers: active_servers,
      inactive_servers: inactive_servers |> Enum.map(& &1.id) |> MapSet.new(),
      server_state_map: ServerTracker.server_state_map(active_servers),
      server_tracker: tracker,
      groups: groups
    )
    |> ok()
  end

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
        {:student_updated, %Student{id: student_id} = updated_student},
        %Socket{assigns: %{student: %Student{id: student_id} = student}} = socket
      ),
      do:
        socket
        |> assign(student: Student.refresh!(student, updated_student))
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
        {:class_updated, %Class{id: id} = updated_class, _event},
        %Socket{
          assigns: %{
            student: %Student{class: %Class{id: id} = class} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: %Student{student | class: Class.refresh!(class, updated_class)})
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
          server_state_map: ServerTracker.update_server_state_map(server_state_map, update)
        )
        |> noreply()

  @impl LiveView
  def handle_info(
        {:server_created, %Server{owner_id: owner_id, active: true} = created_server},
        %{
          assigns: %{
            auth: %Authentication{principal_id: owner_id},
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker
          }
        } = socket
      ) do
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

  def handle_info(
        {:server_created, inactive_server},
        %Socket{assigns: %{inactive_servers: inactive_servers}} = socket
      ) do
    socket
    |> assign(inactive_servers: MapSet.put(inactive_servers, inactive_server.id))
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_updated,
         %Server{id: server_id, owner_id: owner_id, active: true} = updated_server},
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
    [updated_servers, updated_server_state_map] =
      if Enum.any?(servers, &(&1.id == server_id)) do
        [
          Enum.map(servers, fn
            %Server{id: ^server_id} ->
              updated_server

            other_server ->
              other_server
          end),
          server_state_map
        ]
      else
        [
          [updated_server | servers],
          ServerTracker.update_server_state_map(
            server_state_map,
            ServerTracker.track(tracker, updated_server)
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

  @impl LiveView
  def handle_info(
        {:server_updated, %Server{id: server_id} = server},
        %{
          assigns: %{
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker,
            inactive_servers: inactive_servers
          }
        } = socket
      ) do
    if Enum.any?(servers, &(&1.id == server_id)) do
      socket
      |> assign(
        servers: Enum.reject(servers, fn current_server -> current_server.id == server_id end),
        server_state_map:
          ServerTracker.update_server_state_map(
            server_state_map,
            ServerTracker.untrack(tracker, server)
          ),
        inactive_servers: MapSet.put(inactive_servers, server_id)
      )
      |> noreply()
    else
      socket
      |> assign(inactive_servers: MapSet.put(inactive_servers, server_id))
      |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:server_deleted, %Server{id: server_id} = server},
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
      server_state_map:
        ServerTracker.update_server_state_map(
          server_state_map,
          ServerTracker.untrack(tracker, server)
        ),
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
