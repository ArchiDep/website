defmodule ArchiDepWeb.Channels.UserChannel do
  @moduledoc """
  User channel to connect the static frontend to the backend.
  """

  use ArchiDepWeb, :channel

  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDepWeb.ClientCloudServerData
  alias ArchiDepWeb.ClientSessionData
  alias Phoenix.Channel

  @impl Channel
  def join("me", _message, socket) do
    auth = socket.assigns.auth

    {:ok, student} =
      if root?(auth) do
        {:ok, nil}
      else
        Course.fetch_authenticated_student(auth)
      end

    if student do
      :ok = Course.PubSub.subscribe_class(student.class_id)
      :ok = Course.PubSub.subscribe_student(student.id)
    end

    :ok = Servers.PubSub.subscribe_server_owner_servers(auth.principal_id)

    now = DateTime.utc_now()
    active_servers = auth |> Servers.list_my_servers() |> Enum.filter(&Server.active?(&1, now))

    send(self(), :after_join)

    socket
    |> assign(active_servers: active_servers, student: student)
    |> ok_with(ClientSessionData.new(auth))
  end

  @impl Channel
  def handle_info(:after_join, socket), do: socket |> send_active_server_data() |> noreply()

  @impl Channel
  def handle_info(
        {:class_updated, %Class{id: id} = updated_class, _event},
        %Socket{
          assigns: %{
            active_servers: active_servers,
            student: %Student{class: %Class{id: id} = current_class} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers: update_class_of_active_servers(active_servers, updated_class),
          student: %Student{student | class: Class.refresh!(current_class, updated_class)}
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:class_deleted, %Class{id: id} = deleted_class},
        %Socket{
          assigns: %{active_servers: active_servers, student: %Student{class: %Class{id: id}}}
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers: remove_active_servers_of_class(active_servers, deleted_class),
          student: nil
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:student_updated, %Student{id: id} = updated_student},
        %Socket{
          assigns: %{
            active_servers: active_servers,
            student: %Student{id: id} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers: update_student_of_active_servers(active_servers, updated_student),
          student: Student.refresh!(student, updated_student)
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:student_deleted, %Student{id: student_id} = deleted_student},
        %Socket{
          assigns: %{active_servers: active_servers, student: %Student{id: student_id}}
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers: remove_active_servers_of_student(active_servers, deleted_student),
          student: nil
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:server_created, %Server{owner_id: principal_id} = created_server},
        %Socket{
          assigns: %{
            auth: %Authentication{principal_id: principal_id},
            active_servers: active_servers
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers:
            add_created_server_if_active(active_servers, created_server, DateTime.utc_now())
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:server_updated, %Server{owner_id: principal_id} = updated_server},
        %Socket{
          assigns: %{
            auth: %Authentication{principal_id: principal_id},
            active_servers: active_servers
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers:
            add_or_remove_updated_server(active_servers, updated_server, DateTime.utc_now())
        )
        |> send_active_server_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:server_deleted, %Server{owner_id: principal_id} = deleted_server},
        %Socket{
          assigns: %{
            auth: %Authentication{principal_id: principal_id},
            active_servers: active_servers
          }
        } = socket
      ),
      do:
        socket
        |> assign(active_servers: delete_server(active_servers, deleted_server))
        |> send_active_server_data()
        |> noreply()

  defp update_class_of_active_servers(active_servers, %Class{id: class_id} = updated_class),
    do:
      Enum.map(active_servers, fn
        %Server{group: %ServerGroup{id: ^class_id} = group} = server ->
          %Server{server | group: ServerGroup.refresh!(group, updated_class)}

        server ->
          server
      end)

  defp remove_active_servers_of_class(active_servers, %Class{id: class_id}),
    do: Enum.reject(active_servers, &(&1.group_id == class_id))

  defp update_student_of_active_servers(
         active_servers,
         %Student{id: student_id} = updated_student
       ),
       do:
         Enum.map(active_servers, fn
           %Server{
             owner: %ServerOwner{group_member: %ServerGroupMember{id: ^student_id} = group_member}
           } = server ->
             %Server{
               server
               | owner: %ServerOwner{
                   server.owner
                   | group_member: ServerGroupMember.refresh!(group_member, updated_student)
                 }
             }

           server ->
             server
         end)

  defp remove_active_servers_of_student(active_servers, %Student{id: student_id}),
    do:
      Enum.reject(active_servers, fn
        %Server{
          owner: %ServerOwner{group_member: %ServerGroupMember{id: ^student_id}}
        } ->
          true

        _other ->
          false
      end)

  defp send_active_server_data(
         %Socket{
           assigns: %{active_servers: [active_server], student: student}
         } = socket
       ) do
    push(
      socket,
      "cloudServerData",
      student
      |> ClientCloudServerData.new({active_server, ~p"/servers/#{active_server.id}"})
      |> Map.from_struct()
    )

    socket
  end

  defp send_active_server_data(%Socket{assigns: %{student: student}} = socket) do
    push(
      socket,
      "cloudServerData",
      student |> ClientCloudServerData.new(nil) |> Map.from_struct()
    )

    socket
  end

  defp add_created_server_if_active(active_servers, created_server, now)
       when is_struct(now, DateTime),
       do:
         add_created_server(
           active_servers,
           created_server,
           Server.active?(created_server, now)
         )

  defp add_created_server(active_servers, created_server, true),
    do: add_active_server(active_servers, created_server)

  defp add_created_server(active_servers, _created_server, false), do: active_servers

  defp add_or_remove_updated_server(active_servers, updated_server, now)
       when is_struct(now, DateTime),
       do:
         add_or_remove_updated_server(
           active_servers,
           updated_server,
           Server.active?(updated_server, now)
         )

  defp add_or_remove_updated_server(active_servers, %Server{id: server_id}, false),
    do: Enum.reject(active_servers, &(&1.id == server_id))

  defp add_or_remove_updated_server(active_servers, updated_server, true),
    do: add_active_server(active_servers, updated_server)

  defp delete_server(active_servers, %Server{id: server_id}),
    do: Enum.reject(active_servers, &(&1.id == server_id))

  defp add_active_server(active_servers, %Server{id: server_id, active: true} = active_server),
    do:
      active_servers
      |> Enum.reduce({[], false}, fn
        %Server{id: ^server_id}, acc -> {[active_server | acc], true}
        server, {acc, found} -> {[server | acc], found}
      end)
      |> then(fn
        {updated_servers, true} -> updated_servers
        {_updated_servers, false} -> [active_server | active_servers]
      end)
end
