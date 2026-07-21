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
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias ArchiDepWeb.Course.ChangeUsernameDialogLive
  alias ArchiDepWeb.Dashboard.Components.WhatIsYourNameLive
  alias ArchiDepWeb.LiveRefresh
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

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.PubSub.subscribe_student(student.id)
        :ok = Course.PubSub.subscribe_class(student.class_id)
      end

      :ok = Servers.subscribe_my_servers(auth)
      {:ok, _tracker} = ServerTrackerClient.start_link(auth, servers, :active)
    end

    socket
    |> assign(
      page_title: gettext("Dashboard"),
      now: Clock.now(),
      student: student,
      ssh_exercise_vm_md5_host_key_fingerprints: ssh_exercise_vm_md5_host_key_fingerprints,
      ssh_exercise_vm_sha256_host_key_fingerprints: ssh_exercise_vm_sha256_host_key_fingerprints,
      servers: servers,
      server_state_map: ServerTrackerClient.server_state_map(servers),
      groups: groups
    )
    |> attach_server_refreshers()
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

  # On connected mount, keep both server read-models current through the Servers
  # boundary: the list refresher owns creation, update, deletion and ordering,
  # and the state-map refresher folds the real-time states the self-managing
  # tracker pushes. The tracker watches this owner's active servers on its own,
  # so the page names no server topics or events. Student and class updates keep
  # their own handlers above.
  defp attach_server_refreshers(socket) do
    if connected?(socket) do
      auth = socket.assigns.auth

      socket
      |> LiveRefresh.attach(:servers, &Servers.refresh_my_servers(auth, &1, &2))
      |> LiveRefresh.attach(:server_state_map, &Servers.refresh_server_state_map/2)
    else
      socket
    end
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

  defp active_servers(servers), do: Enum.filter(servers, & &1.active)

  defp any_inactive_servers?(servers), do: Enum.any?(servers, &(not &1.active))
end
