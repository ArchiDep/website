defmodule ArchiDepWeb.Channels.UserChannel do
  @moduledoc """
  User channel to connect the static frontend to the backend.
  """

  use ArchiDepWeb, :channel

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.ClassHelpers, only: [class_updated_id: 1]
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerView
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

    now = Clock.now()

    active_servers =
      auth |> Servers.list_my_servers() |> Enum.filter(&ServerView.active?(&1, now))

    current_client_session_data = ClientSessionData.new(auth, student)

    send(self(), :after_join)

    socket
    |> assign(
      active_servers: active_servers,
      student: student,
      current_client_session_data: current_client_session_data,
      current_cloud_server_data: nil
    )
    |> ok_with(current_client_session_data)
  end

  @impl Channel
  def handle_info(:after_join, socket), do: socket |> send_updated_data() |> noreply()

  @impl Channel
  def handle_info(
        {:class_updated, event, reference},
        %Socket{
          assigns: %{
            active_servers: active_servers,
            student: %Student{class: %Class{} = current_class} = student
          }
        } = socket
      ),
      do:
        socket
        |> assign(
          active_servers: update_class_of_active_servers(active_servers, event, reference),
          student: %Student{student | class: Class.refresh!(current_class, event, reference)}
        )
        |> send_updated_data()
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
        |> send_updated_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:student_updated, %{id: id} = event, reference},
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
          active_servers: update_student_of_active_servers(active_servers, event, reference),
          student: Student.refresh!(student, event, reference)
        )
        |> send_updated_data()
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
        |> send_updated_data()
        |> noreply()

  @impl Channel
  def handle_info(
        {:server_created, %ServerCreated{owner: %{id: principal_id}} = event, _reference},
        %Socket{
          assigns: %{
            auth: %Authentication{principal_id: principal_id} = auth,
            active_servers: active_servers
          }
        } = socket
      ) do
    updated_active_servers =
      case Servers.fetch_server(auth, event.id) do
        {:ok, created_server} ->
          add_created_server_if_active(active_servers, created_server, Clock.now())

        {:error, _reason} ->
          active_servers
      end

    socket
    |> assign(active_servers: updated_active_servers)
    |> send_updated_data()
    |> noreply()
  end

  @impl Channel
  def handle_info(
        {:server_updated, event, reference},
        %Socket{
          assigns: %{
            auth: auth,
            active_servers: active_servers
          }
        } = socket
      ) do
    server_id = event.id

    updated_active_servers =
      case Enum.find(active_servers, &(&1.id == server_id)) do
        %ServerView{} = cached ->
          add_or_remove_updated_server(
            active_servers,
            ServerView.refresh!(cached, event, reference),
            Clock.now()
          )

        nil ->
          case Servers.fetch_server(auth, server_id) do
            {:ok, server} ->
              add_or_remove_updated_server(active_servers, server, Clock.now())

            {:error, _reason} ->
              Enum.reject(active_servers, &(&1.id == server_id))
          end
      end

    socket
    |> assign(active_servers: updated_active_servers)
    |> send_updated_data()
    |> noreply()
  end

  @impl Channel
  def handle_info(
        {:server_deleted, %ServerDeleted{owner: %{id: principal_id}} = event, _reference},
        %Socket{
          assigns: %{
            auth: %Authentication{principal_id: principal_id},
            active_servers: active_servers
          }
        } = socket
      ),
      do:
        socket
        |> assign(active_servers: delete_server(active_servers, event))
        |> send_updated_data()
        |> noreply()

  defp update_class_of_active_servers(active_servers, event, reference) do
    class_id = class_updated_id(event)

    Enum.map(active_servers, fn
      %ServerView{group: %ServerGroup{id: ^class_id} = group} = server ->
        %ServerView{server | group: ServerGroup.refresh!(group, event, reference)}

      server ->
        server
    end)
  end

  defp remove_active_servers_of_class(active_servers, %Class{id: class_id}),
    do: Enum.reject(active_servers, &(&1.group_id == class_id))

  defp update_student_of_active_servers(
         active_servers,
         %{id: student_id} = event,
         reference
       ),
       do:
         Enum.map(active_servers, fn
           %ServerView{
             owner: %ServerOwner{group_member: %ServerGroupMember{id: ^student_id} = group_member}
           } = server ->
             %ServerView{
               server
               | owner: %ServerOwner{
                   server.owner
                   | group_member: ServerGroupMember.refresh!(group_member, event, reference)
                 }
             }

           server ->
             server
         end)

  defp remove_active_servers_of_student(active_servers, %Student{id: student_id}),
    do:
      Enum.reject(active_servers, fn
        %ServerView{
          owner: %ServerOwner{group_member: %ServerGroupMember{id: ^student_id}}
        } ->
          true

        _other ->
          false
      end)

  defp send_updated_data(socket),
    do:
      socket
      |> send_new_client_session_data()
      |> send_cloud_server_data()

  defp send_new_client_session_data(
         %Socket{
           assigns: %{
             auth: auth,
             student: student,
             current_client_session_data: current_client_session_data
           }
         } = socket
       ) do
    new_client_session_data = ClientSessionData.new(auth, student)

    if new_client_session_data == current_client_session_data do
      socket
    else
      push(socket, "session", Map.from_struct(new_client_session_data))
      assign(socket, current_client_session_data: new_client_session_data)
    end
  end

  defp send_cloud_server_data(
         %Socket{
           assigns: %{active_servers: [active_server], student: student}
         } = socket
       ),
       do:
         send_new_cloud_server_data(
           socket,
           ClientCloudServerData.new(student, {active_server, ~p"/servers/#{active_server.id}"})
         )

  defp send_cloud_server_data(%Socket{assigns: %{student: student}} = socket),
    do: send_new_cloud_server_data(socket, ClientCloudServerData.new(student, nil))

  defp send_new_cloud_server_data(
         %Socket{assigns: %{current_cloud_server_data: cloud_server_data}} = socket,
         cloud_server_data
       ) do
    socket
  end

  defp send_new_cloud_server_data(socket, new_cloud_server_data) do
    push(socket, "cloudServerData", Map.from_struct(new_cloud_server_data))
    assign(socket, current_cloud_server_data: new_cloud_server_data)
  end

  defp add_created_server_if_active(active_servers, created_server, now)
       when is_struct(now, DateTime),
       do:
         add_created_server(
           active_servers,
           created_server,
           ServerView.active?(created_server, now)
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
           ServerView.active?(updated_server, now)
         )

  defp add_or_remove_updated_server(active_servers, %ServerView{id: server_id}, false),
    do: Enum.reject(active_servers, &(&1.id == server_id))

  defp add_or_remove_updated_server(active_servers, updated_server, true),
    do: add_active_server(active_servers, updated_server)

  defp delete_server(active_servers, %ServerDeleted{id: server_id}),
    do: Enum.reject(active_servers, &(&1.id == server_id))

  defp add_active_server(
         active_servers,
         %ServerView{id: server_id, active: true} = active_server
       ),
       do:
         active_servers
         |> Enum.reduce({[], false}, fn
           %ServerView{id: ^server_id}, {acc, _found} -> {[active_server | acc], true}
           server, {acc, found} -> {[server | acc], found}
         end)
         |> then(fn
           {updated_servers, true} -> updated_servers
           {_updated_servers, false} -> [active_server | active_servers]
         end)

  defp add_active_server(active_servers, _inactive_server), do: active_servers
end
