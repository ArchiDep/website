defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner do
  require Logger
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.ServerManager
  alias Ecto.UUID
  alias Phoenix.Tracker

  @tracker ArchiDep.Tracker

  @spec start_link(any()) :: {:ok, pid()}
  def start_link({run_id, run_ref}), do: Task.start_link(fn -> process_event(run_id, run_ref) end)

  @spec process_event(UUID.t(), reference()) :: :ok
  def process_event(run_id, run_ref) do
    track!(run_id, %{state: :pending, events: 0})

    running_run =
      run_id
      |> AnsiblePlaybookRun.get_pending_run!()
      |> AnsiblePlaybookRun.start_running()
      |> Repo.update!()

    update_tracking!(run_id, fn meta -> %{meta | state: :running} end)

    :ok =
      running_run
      |> Ansible.run_playbook()
      |> Stream.each(fn
        {:event, _event} ->
          update_tracking!(run_id, fn meta -> %{meta | events: meta.events + 1} end)

        {:succeeded, succeeded_run} ->
          update_tracking!(run_id, fn meta -> %{meta | state: :succeeded} end)
          :ok = ServerManager.ansible_playbook_completed(succeeded_run, run_ref)

        {:failed, failed_run} ->
          update_tracking!(run_id, fn meta -> %{meta | state: :failed} end)
          :ok = ServerManager.ansible_playbook_completed(failed_run, run_ref)
      end)
      |> Stream.run()
  end

  defp track!(run_id, meta) do
    {:ok, _ref} =
      Tracker.track(@tracker, self(), "ansible-playbooks", run_id, meta)
  end

  defp update_tracking!(run_id, update) do
    {:ok, _ref} =
      Tracker.update(@tracker, self(), "ansible-playbooks", run_id, update)
  end
end
