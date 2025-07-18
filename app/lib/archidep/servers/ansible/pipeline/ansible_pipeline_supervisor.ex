defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineSupervisor do
  @moduledoc """
  Supervisor for the Ansible pipeline that manages the queue and consumer
  responsible for processing playbook runs.
  """

  use Supervisor

  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineConsumer
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue

  @spec name(Pipeline.t()) :: GenServer.name()
  def name(pipeline), do: {:global, {__MODULE__, pipeline}}

  @spec start_link(Pipeline.t()) :: Supervisor.on_start()
  def start_link(pipeline), do: Supervisor.start_link(__MODULE__, pipeline, name: name(pipeline))

  @impl true
  def init(pipeline) do
    set_process_label(__MODULE__)

    children = [
      {AnsiblePipelineQueue, pipeline},
      {AnsiblePipelineConsumer, pipeline}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
