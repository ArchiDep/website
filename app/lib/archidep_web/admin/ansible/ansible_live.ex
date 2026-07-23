defmodule ArchiDepWeb.Admin.Ansible.AnsibleLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.Ansible.AnsibleComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Servers
  require Logger

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    tracked_playbooks =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)
        :ok = Servers.subscribe_ansible_playbook_runs()
        Servers.tracked_ansible_playbook_runs()
      else
        %{}
      end

    socket
    |> assign(
      page_title: "#{gettext("Ansible")} · #{gettext("Admin")}",
      now: Clock.now(),
      playbook_runs: Servers.fetch_ansible_playbook_runs(auth),
      tracked_playbooks: tracked_playbooks,
      next_tick: nil
    )
    |> tick()
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)

  @impl LiveView
  def handle_info(
        {_action, _key, %{}} = message,
        %Socket{
          assigns: %{
            auth: auth,
            playbook_runs: playbook_runs,
            tracked_playbooks: tracked_playbooks
          }
        } = socket
      ) do
    case Servers.refresh_ansible_playbook_runs(auth, playbook_runs, tracked_playbooks, message) do
      {:ok, new_playbook_runs, new_tracked_playbooks} ->
        socket
        |> assign(
          playbook_runs: new_playbook_runs,
          tracked_playbooks: new_tracked_playbooks
        )
        |> tick()
        |> noreply()

      :ignore ->
        noreply(socket)
    end
  end

  @impl LiveView
  def handle_info(:tick, socket),
    do:
      socket
      |> assign(now: Clock.now(), next_tick: nil)
      |> tick()
      |> noreply()

  defp tick(socket) do
    if connected?(socket) do
      interval = tick_interval(socket)
      assign(socket, :next_tick, reset_tick(socket, interval))
    else
      socket
    end
  end

  defp reset_tick(%Socket{assigns: %{next_tick: next_tick}}, in_seconds) do
    {cancel, schedule} =
      case {next_tick, in_seconds} do
        {nil, false} ->
          {false, false}

        {{_old_seconds, old_ref}, false} ->
          {old_ref, false}

        {nil, _seconds} ->
          {false, in_seconds}

        {{old_seconds, old_ref}, new_seconds} when new_seconds < old_seconds ->
          {old_ref, new_seconds}

        {_previous, _seconds} ->
          {false, false}
      end

    if cancel do
      Process.cancel_timer(cancel)
    end

    if schedule do
      Logger.debug("Next tick in #{in_seconds} second(s)")
      ref = Process.send_after(self(), :tick, in_seconds * 1000)
      {in_seconds, ref}
    else
      next_tick
    end
  end

  defp tick_interval(%Socket{assigns: %{tracked_playbooks: tracked_playbooks}})
       when tracked_playbooks != %{},
       do: 1

  defp tick_interval(%Socket{assigns: %{playbook_runs: []}}), do: false

  defp tick_interval(%Socket{assigns: %{playbook_runs: [most_recent_run | _other_runs]}}) do
    last_run_minutes_ago =
      most_recent_run.created_at
      |> DateTime.diff(Clock.now(), :second)
      |> abs()
      |> div(60)

    Logger.debug("Last Ansible playbook run was #{last_run_minutes_ago} minute(s) ago")

    case last_run_minutes_ago do
      n when n < 1 -> 1
      n when n < 5 -> 30
      _otherwise -> 60
    end
  end
end
