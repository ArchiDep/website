defmodule ArchiDepWeb.Admin.Ansible.AnsibleLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Admin.Ansible.AnsibleComponents
  import ArchiDepWeb.Helpers.LiveViewHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Phoenix.PubSub
  alias Phoenix.Tracker
  require Logger

  @pubsub ArchiDep.PubSub
  @tracker ArchiDep.Tracker

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    tracked_playbooks =
      if connected?(socket) do
        set_process_label(__MODULE__, auth)
        :ok = PubSub.subscribe(@pubsub, "tracker:ansible-playbooks")

        @tracker
        |> Tracker.list("ansible-playbooks")
        |> Enum.reduce(%{}, fn {key, meta}, acc -> Map.put(acc, key, meta) end)
      else
        %{}
      end

    socket
    |> assign(
      page_title: "#{gettext("Ansible")} · #{gettext("Admin")}",
      now: DateTime.utc_now(),
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
        {action, run_id, %{state: state, events: events} = meta},
        %Socket{assigns: %{playbook_runs: playbook_runs, tracked_playbooks: tracked_playbooks}} =
          socket
      )
      when action in [:join, :update] do
    new_tracked_playbooks =
      Map.update(tracked_playbooks, run_id, meta, fn %{state: old_state, events: old_events} =
                                                       old_meta ->
        if events > old_events or
             ansible_playbook_run_state_order(state) >
               ansible_playbook_run_state_order(old_state) do
          meta
        else
          old_meta
        end
      end)

    new_meta = Map.get(new_tracked_playbooks, run_id)

    new_playbook_runs =
      if Enum.any?(playbook_runs, &(&1.id === run_id)) do
        Enum.map(playbook_runs, fn
          %AnsiblePlaybookRun{id: ^run_id} = run ->
            %AnsiblePlaybookRun{run | state: new_meta.state, number_of_events: new_meta.events}

          other_run ->
            other_run
        end)
      else
        new_run = run_id |> AnsiblePlaybookRun.fetch_run() |> unpair_ok()
        add_new_playbook_run(playbook_runs, new_run)
      end

    socket
    |> assign(
      playbook_runs: new_playbook_runs,
      tracked_playbooks: new_tracked_playbooks
    )
    |> tick()
    |> noreply()
  end

  @impl LiveView
  def handle_info(
        {:leave, run_id, %{}},
        %Socket{assigns: %{playbook_runs: playbook_runs, tracked_playbooks: tracked_playbooks}} =
          socket
      ),
      do:
        socket
        |> assign(
          playbook_runs:
            Enum.map(playbook_runs, fn
              %AnsiblePlaybookRun{id: ^run_id} ->
                run_id |> AnsiblePlaybookRun.fetch_run() |> unpair_ok()

              other_run ->
                other_run
            end),
          tracked_playbooks: Map.delete(tracked_playbooks, run_id)
        )
        |> noreply()

  @impl LiveView
  def handle_info(:tick, socket),
    do:
      socket
      |> assign(now: DateTime.utc_now(), next_tick: nil)
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
      |> DateTime.diff(DateTime.utc_now(), :second)
      |> abs()
      |> div(60)

    Logger.debug("Last Ansible playbook run was #{last_run_minutes_ago} minute(s) ago")

    case last_run_minutes_ago do
      n when n < 1 -> 1
      n when n < 5 -> 30
      _otherwise -> 60
    end
  end

  defp ansible_playbook_run_state_order(:pending), do: 1
  defp ansible_playbook_run_state_order(:running), do: 2
  defp ansible_playbook_run_state_order(_final_state), do: 3

  defp add_new_playbook_run([], new_run), do: [new_run]

  defp add_new_playbook_run(
         [%AnsiblePlaybookRun{created_at: most_recent_run_created_at} | _other_runs] =
           current_runs,
         %AnsiblePlaybookRun{created_at: new_run_created_at} = new_run
       )
       when new_run_created_at > most_recent_run_created_at,
       do: [new_run | current_runs]

  defp add_new_playbook_run(playbook_runs, new_run),
    do:
      playbook_runs
      |> Enum.reduce({new_run, []}, fn
        %AnsiblePlaybookRun{created_at: created_at} = existing_run,
        {%AnsiblePlaybookRun{created_at: new_run_created_at} = run_to_add, acc}
        when new_run_created_at > created_at ->
          {nil, [existing_run | [run_to_add | acc]]}

        existing_run, {run_to_add, acc} ->
          {run_to_add, [existing_run | acc]}
      end)
      |> elem(1)
      |> Enum.reverse()
end
