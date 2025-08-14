defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerHelpComponent
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive
  alias ArchiDepWeb.Servers.NewServerDialogLive

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    [student, servers, groups] =
      Task.await_many([
        Task.async(fn -> fetch_student(auth) end),
        Task.async(fn -> Servers.list_my_active_servers(auth) end),
        if(has_role?(auth, :root),
          do: Task.async(fn -> Servers.list_server_groups(auth) end),
          else: Task.completed(nil)
        )
      ])

    tracker =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)

        if student != nil do
          :ok = Course.PubSub.subscribe_student(student.id)
          :ok = Course.PubSub.subscribe_class(student.class_id)
        end

        for server <- servers do
          # TODO: add watch_my_servers in context
          :ok = PubSub.subscribe_server(server.id)
        end

        :ok = PubSub.subscribe_server_owner_servers(auth.principal_id)

        {:ok, pid} = ServerTracker.start_link(servers)
        pid
      else
        nil
      end

    socket
    |> assign(
      student: student,
      servers: servers,
      server_state_map: ServerTracker.server_state_map(servers),
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
        {:class_updated, %Class{id: id} = updated_class},
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

  def handle_info({:server_created, _unrelated_server}, socket) do
    noreply(socket)
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
            server_tracker: tracker
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
    |> assign(servers: sort_servers(updated_servers), server_state_map: updated_server_state_map)
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:server_updated, %Server{id: server_id} = server},
        %{
          assigns: %{
            servers: servers,
            server_state_map: server_state_map,
            server_tracker: tracker
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
          )
      )
      |> noreply()
    else
      noreply(socket)
    end
  end

  @impl LiveView
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

  defp fetch_student(auth) do
    {:ok, student} =
      if has_role?(auth, :student) do
        Course.fetch_authenticated_student(auth)
      else
        {:ok, nil}
      end

    student
  end

  defp sort_servers(servers),
    do: Enum.sort_by(servers, &{&1.name, &1.username, :inet.ntoa(&1.ip_address.address)})
end
