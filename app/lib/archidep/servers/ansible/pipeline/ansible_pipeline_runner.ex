defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner do
  require Logger
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  @spec start_link(any()) :: {:ok, pid()}
  def start_link(event), do: Task.start_link(fn -> process_event(event) end)

  defp process_event({run_id, run_ref}) do
    run = AnsiblePlaybookRun.get_pending_run!(run_id)
    Logger.warning("Process event: #{inspect(run_ref)} #{inspect(run)}")
  end
end
