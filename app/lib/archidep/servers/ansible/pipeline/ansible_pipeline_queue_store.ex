defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStore do
  @moduledoc """
  Default store for the Ansible pipeline queue. When the queue boots, any
  playbook run left in a non-terminal state (e.g. because the node crashed or
  restarted mid-run) is marked as timed out, recording a run-finished event for
  each.
  """

  @behaviour ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreBehaviour

  import ArchiDep.Helpers.UseCaseHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Events.AnsiblePlaybookRunFinished
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias Ecto.Multi
  require Logger

  @impl ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreBehaviour
  @spec mark_incomplete_runs_as_timed_out() :: :ok
  def mark_incomplete_runs_as_timed_out do
    incomplete_runs = AnsiblePlaybookRun.fetch_incomplete_runs()

    if Enum.any?(incomplete_runs) do
      Task.await_many(
        Enum.map(
          incomplete_runs,
          &Task.async(fn -> mark_incomplete_playbook_run_as_timed_out(&1) end)
        )
      )

      incomplete_runs_nb = length(incomplete_runs)
      Logger.notice("Marked #{incomplete_runs_nb} incomplete playbook runs as timed out")
    end

    :ok
  end

  defp mark_incomplete_playbook_run_as_timed_out(run),
    do:
      Multi.new()
      |> Multi.update(:run, AnsiblePlaybookRun.time_out(run, Clock.now()))
      |> Multi.insert(:stored_event, &ansible_playbook_run_finished(&1.run))
      |> Repo.transaction()

  defp ansible_playbook_run_finished(run),
    do:
      run
      |> AnsiblePlaybookRunFinished.new()
      |> new_event(%{}, occurred_at: run.finished_at)
      |> add_to_stream(run.server)
      |> initiated_by(run.server)
end
