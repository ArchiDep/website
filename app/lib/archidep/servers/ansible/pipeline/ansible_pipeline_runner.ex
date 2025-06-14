defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner do
  require Logger

  @spec start_link(any()) :: {:ok, pid()}
  def start_link(event), do: Task.start_link(fn -> process_event(event) end)

  defp process_event(event) do
    Logger.warning("Process event: #{inspect(event)}")
  end
end
