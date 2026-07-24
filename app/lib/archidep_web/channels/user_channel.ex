defmodule ArchiDepWeb.Channels.UserChannel do
  @moduledoc """
  User channel to connect the static frontend to the backend.
  """

  use ArchiDepWeb, :channel

  import ArchiDepWeb.Helpers.AuthHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.StudentView
  alias ArchiDep.Servers
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

    if student != nil do
      :ok = Course.subscribe_student_detail(student)
    end

    :ok = Servers.subscribe_my_servers(auth)

    servers = Servers.list_my_servers(auth)
    current_client_session_data = ClientSessionData.new(auth, student)

    send(self(), :after_join)

    socket
    |> assign(
      servers: servers,
      student: student,
      current_client_session_data: current_client_session_data,
      current_cloud_server_data: nil
    )
    |> ok_with(current_client_session_data)
  end

  @impl Channel
  def handle_info(:after_join, socket), do: socket |> send_updated_data() |> noreply()

  # A class or student deletion ends the student's presence: drop the student
  # and its servers so the browser widget clears. The refreshers below do not
  # claim a deletion (it is terminal, not a merge), so it falls through to here.
  @impl Channel
  def handle_info(
        {:class_deleted, %Class{id: class_id}},
        %Socket{assigns: %{student: %StudentView{class_id: class_id}}} = socket
      ),
      do: socket |> assign(student: nil, servers: []) |> send_updated_data() |> noreply()

  @impl Channel
  def handle_info(
        {:student_deleted, %Student{id: student_id}},
        %Socket{assigns: %{student: %StudentView{id: student_id}}} = socket
      ),
      do: socket |> assign(student: nil, servers: []) |> send_updated_data() |> noreply()

  # Every other broadcast is reconciled through the owning contexts: the student
  # (with its nested class) via Course, the owner's server list via Servers. The
  # channel names no events; a message that concerns neither leaves both
  # unchanged, so `send_updated_data/1` pushes nothing.
  @impl Channel
  def handle_info(
        message,
        %Socket{assigns: %{auth: auth, student: student, servers: servers}} = socket
      ),
      do:
        socket
        |> assign(
          student: reconcile(Course.refresh_student_detail(student, message), student),
          servers: reconcile(Servers.refresh_my_servers(auth, servers, message), servers)
        )
        |> send_updated_data()
        |> noreply()

  defp reconcile({:ok, updated}, _current), do: updated
  defp reconcile(:ignore, current), do: current

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

  defp send_cloud_server_data(%Socket{assigns: %{servers: servers, student: student}} = socket),
    do:
      send_new_cloud_server_data(
        socket,
        ClientCloudServerData.new(student, active_server(servers))
      )

  # The browser widget shows a single cloud server, so it is populated only when
  # exactly one of the owner's servers is active at the current instant.
  defp active_server(servers) do
    now = Clock.now()

    case Enum.filter(servers, &ServerView.active?(&1, now)) do
      [active_server] -> {active_server, ~p"/servers/#{active_server.id}"}
      _other -> nil
    end
  end

  defp send_new_cloud_server_data(
         %Socket{assigns: %{current_cloud_server_data: cloud_server_data}} = socket,
         cloud_server_data
       ),
       do: socket

  defp send_new_cloud_server_data(socket, new_cloud_server_data) do
    push(socket, "cloudServerData", Map.from_struct(new_cloud_server_data))
    assign(socket, current_cloud_server_data: new_cloud_server_data)
  end
end
