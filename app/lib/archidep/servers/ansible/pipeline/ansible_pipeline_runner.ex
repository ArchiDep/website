defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner do
  @moduledoc """
  Runner that executes playbook runs from the queue. It starts a task for each
  playbook run and ensures that the playbook is executed only if the server is
  online. It then runs the actual Ansible playbook and saves the events as they
  come in.
  """

  import ArchiDep.Helpers.UseCaseHelpers
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunRunning
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias Ecto.Multi
  alias Ecto.UUID
  alias Phoenix.Tracker
  require Logger

  @tracker ArchiDep.Tracker
  @event_base [:archidep, :servers, :ansible, :playbook_run]

  @spec start_link({UUID.t(), EventReference.t()}) :: {:ok, pid()}
  def start_link({run_id, cause}),
    do:
      Task.start_link(fn ->
        process_event(run_id, cause)
      end)

  @spec process_event(UUID.t(), EventReference.t()) :: :ok
  def process_event(run_id, cause) do
    case AnsiblePlaybookRun.get_pending_run(run_id) do
      nil ->
        Logger.warning("No pending Ansible playbook run found with ID #{run_id}")

      pending_run ->
        process_pending_run(pending_run, cause)
    end

    :ok
  end

  defp process_pending_run(pending_run, cause) do
    if ServerManager.online?(pending_run.server) do
      :telemetry.span(
        @event_base,
        start_event_metadata(pending_run),
        fn ->
          finished_run =
            pending_run |> run_playbook(cause) |> finished_run_from_result()

          {finished_run, finished_event_metadata(finished_run)}
        end
      )
    else
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.interrupt(pending_run))
      |> Multi.insert(:stored_event, &ansible_playbook_run_finished(&1.run, cause))
      |> Repo.transaction()
      |> then(fn {:ok, %{run: interrupted_run}} ->
        :telemetry.execute(
          @event_base ++ [:interrupted],
          %{duration: AnsiblePlaybookRun.duration(interrupted_run)},
          finished_event_metadata(interrupted_run)
        )
      end)
    end
  end

  defp run_playbook(%AnsiblePlaybookRun{id: run_id} = pending_run, cause) do
    track!(run_id, %{state: :pending, events: 0, current_task: nil})

    {:ok, %{run: running_run, stored_event: running_event}} =
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.start_running(pending_run))
      |> Multi.insert(:stored_event, &ansible_playbook_run_running(&1.run, cause))
      |> Repo.transaction()

    update_tracking!(run_id, fn meta -> %{meta | state: :running} end)

    running_run
    |> Ansible.run_playbook(cause, StoredEvent.to_reference(running_event))
    |> Stream.each(fn
      {:event, event} ->
        update_tracking!(run_id, fn meta ->
          %{meta | events: meta.events + 1, current_task: event.task_name}
        end)

        :ok = ServerManager.ansible_playbook_event(running_run, event)

      {:succeeded, succeeded_run} ->
        update_tracking!(run_id, fn meta -> %{meta | state: :succeeded, current_task: nil} end)
        :ok = ServerManager.ansible_playbook_completed(succeeded_run)

      {:failed, failed_run} ->
        update_tracking!(run_id, fn meta -> %{meta | state: :failed, current_task: nil} end)
        :ok = ServerManager.ansible_playbook_completed(failed_run)
    end)
    |> Enum.at(-1)
  end

  defp track!(run_id, meta) do
    {:ok, _ref} =
      Tracker.track(@tracker, self(), "ansible-playbooks", run_id, meta)
  end

  defp update_tracking!(run_id, update) do
    {:ok, _ref} =
      Tracker.update(@tracker, self(), "ansible-playbooks", run_id, update)
  end

  defp finished_run_from_result({:succeeded, run}), do: run
  defp finished_run_from_result({:failed, run}), do: run

  defp start_event_metadata(run),
    do: %{
      server_id: run.server_id,
      playbook: run.playbook
    }

  defp finished_event_metadata(run),
    do: %{
      state: run.state,
      server_id: run.server_id,
      playbook: run.playbook
    }

  defp ansible_playbook_run_running(run, cause),
    do:
      run
      |> AnsiblePlaybookRunRunning.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.started_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)

  defp ansible_playbook_run_finished(run, cause),
    do:
      run
      |> AnsiblePlaybookRunFinished.new()
      |> new_event(%{}, caused_by: cause, occurred_at: run.finished_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)
end
