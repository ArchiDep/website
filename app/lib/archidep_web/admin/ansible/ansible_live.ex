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
      page_title: "#{gettext("ArchiDep")} > #{gettext("Admin")} > #{gettext("Ansible")}",
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

    socket
    |> assign(
      playbook_runs:
        Enum.map(playbook_runs, fn
          %AnsiblePlaybookRun{id: ^run_id} = run ->
            %AnsiblePlaybookRun{run | state: new_meta.state, number_of_events: new_meta.events}

          other_run ->
            other_run
        end),
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

  defp tick(
         %Socket{
           assigns: %{
             playbook_runs: playbook_runs,
             tracked_playbooks: tracked_playbooks,
             next_tick: next_tick
           }
         } =
           socket
       ) do
    new_next_tick =
      if connected?(socket) and
           (tracked_playbooks != %{} or
              Enum.any?(playbook_runs, &(not AnsiblePlaybookRun.done?(&1)))) do
        in_seconds =
          if tracked_playbooks != %{} do
            1
          else
            last_run_minutes_ago =
              playbook_runs
              |> Enum.filter(&(not AnsiblePlaybookRun.done?(&1)))
              |> Enum.map(& &1.started_at)
              |> Enum.max()
              |> DateTime.diff(DateTime.utc_now(), :second)
              |> abs()
              |> div(60)

            Logger.debug("Last Ansible playbook run was #{last_run_minutes_ago} minute(s) ago")

            last_run_minutes_ago
            |> min(1)
            |> max(60)
          end

        {previous_seconds, previous_ref} =
          case next_tick do
            nil -> {nil, nil}
            {s, r} -> {s, r}
          end

        if previous_ref == nil or in_seconds < previous_seconds do
          if previous_ref != nil do
            Process.cancel_timer(previous_ref)
          end

          Logger.debug("Next tick in #{in_seconds} second(s)")
          ref = Process.send_after(self(), :tick, in_seconds * 1000)
          {in_seconds, ref}
        else
          next_tick
        end
      end

    assign(socket, :next_tick, new_next_tick)
  end

  defp ansible_playbook_run_state_order(:pending), do: 1
  defp ansible_playbook_run_state_order(:running), do: 2
  defp ansible_playbook_run_state_order(_final_state), do: 3
end
