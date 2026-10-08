defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.AuthHelpers
  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerHelpComponent
  import ArchiDepWeb.Servers.ServerRetryHandlers
  alias ArchiDep.Clock
  alias ArchiDep.Course
  alias ArchiDep.Course.ClassView
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.Events.StudentDeleted
  alias ArchiDep.Course.StudentView
  alias ArchiDep.CourseSite.Material
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
  alias ArchiDep.Servers.SSH
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

    ssh_exercise_vm_host_keys =
      case student do
        %StudentView{class: %ClassView{ssh_exercise_vm_host_keys: keys}} ->
          SSH.stored_ssh_host_keys(keys)

        _not_a_student ->
          []
      end

    if connected?(socket) do
      set_process_label(__MODULE__, auth)

      if student != nil do
        :ok = Course.subscribe_student_detail(student)
      end

      :ok = Servers.subscribe_my_servers(auth)
      {:ok, _tracker} = ServerTrackerClient.start_link(auth, servers, :active)
    end

    socket
    |> assign(
      page_title: gettext("Dashboard"),
      now: Clock.now(),
      student: student,
      ssh_exercise_vm_host_keys: ssh_exercise_vm_host_keys,
      servers: servers,
      server_state_map: ServerTrackerClient.server_state_map(servers),
      groups: groups
    )
    |> attach_refreshers()
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
        {:student_deleted, %StudentDeleted{id: student_id}, _reference},
        %Socket{
          assigns: %{
            student: %StudentView{id: student_id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil, server_group_member: nil)
        |> noreply()

  @impl LiveView
  def handle_info(
        {:class_deleted, %ClassDeleted{id: id}, _reference},
        %Socket{
          assigns: %{
            student: %StudentView{class_id: id}
          }
        } = socket
      ),
      do:
        socket
        |> assign(student: nil)
        |> noreply()

  # On connected mount, keep the student, its server list and the tracker state
  # map current through the Course and Servers boundaries. A `:class_updated` or
  # `:student_updated` refreshes both the student (its nested class) and every
  # server that embeds the changed class or student, so those two share one
  # `attach_all` hook; a server create/update/delete refreshes the list, and the
  # tracker (watching this owner's active servers on its own) feeds the state
  # map. The page names no topics or events; only the two delete notices keep
  # their own handlers above.
  defp attach_refreshers(socket) do
    if connected?(socket) do
      auth = socket.assigns.auth

      socket
      |> LiveRefresh.attach_all([
        {:student, &Course.refresh_student_detail/2},
        {:servers, &Servers.refresh_my_servers(auth, &1, &2)}
      ])
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

  # The student's credentials for the SSH exercise VM and the fingerprints of
  # its host keys, shown on the welcome screen and, once the student can create
  # servers, in a collapsed panel they can still open, since later exercises
  # are done on that VM.
  attr :student, StudentView, required: true
  attr :host_keys, :list, required: true

  defp ssh_exercise_details(assigns) do
    ~H"""
    <div>
      <.data_display class="mt-4" responsive_class="sm:grid-cols-2">
        <.data_display_element title={gettext("Username")}>
          <span class="font-mono">{@student.username}</span>
        </.data_display_element>
        <.data_display_element title={gettext("Password")}>
          <div
            id="student-ssh-exercise-password"
            class="flex justify-center items-center gap-2"
          >
            <div class="toggle-password font-mono">********</div>
            <div class="toggle-password font-mono hidden">
              {@student.ssh_exercise_password}
            </div>
            <.copy_button
              id="student-ssh-exercise-password-copy"
              text={@student.ssh_exercise_password}
            />
            <Heroicons.eye
              class="toggle-password size-4 cursor-pointer text-base-content/75 hover:text-base-content"
              phx-click={
                JS.toggle_class("hidden",
                  to: "#student-ssh-exercise-password .toggle-password"
                )
              }
            />
            <Heroicons.eye_slash
              class="toggle-password size-4 hidden cursor-pointer text-base-content/75 hover:text-base-content"
              phx-click={
                JS.toggle_class("hidden",
                  to: "#student-ssh-exercise-password .toggle-password"
                )
              }
            />
          </div>
        </.data_display_element>
      </.data_display>
      <.ssh_host_key_fingerprints
        id="ssh-exercise-vm-host-key"
        title={gettext("Exercise server SSH host key fingerprints")}
        keys={@host_keys}
        class="mt-4"
      />
    </div>
    """
  end

  # Decides both whether a server card offers the edit button and whether the
  # edit dialog it opens is rendered, so that the two cannot disagree.
  defp editable?(server, state),
    do:
      not ServerView.set_up?(server) and
        ServerRealTimeState.problem?(state, [
          :server_authentication_failed,
          :server_connection_timed_out,
          :server_connection_refused,
          :server_key_exchange_failed
        ])

  defp active_servers(servers), do: Enum.filter(servers, & &1.active)

  defp any_inactive_servers?(servers), do: Enum.any?(servers, &(not &1.active))
end
