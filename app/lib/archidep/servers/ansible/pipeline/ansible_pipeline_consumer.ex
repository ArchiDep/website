defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineConsumer do
  @moduledoc """
  Consumer of the Ansible pipeline queue. It processes pending playbook runs
  from the pipeline queue as they become available, starting a new process for
  each run.
  """

  use ConsumerSupervisor

  require Logger
  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner

  @spec name(Pipeline.t()) :: GenServer.name()
  def name(pipeline), do: {:global, {__MODULE__, pipeline}}

  @spec start_link(Pipeline.t()) :: Supervisor.on_start()
  def start_link(pipeline),
    do: ConsumerSupervisor.start_link(__MODULE__, pipeline, name: name(pipeline))

  @impl true
  def init(pipeline) do
    set_process_label(__MODULE__)

    Logger.info("Init ansible pipeline consumer")

    children = [
      %{
        id: AnsiblePipelineRunner,
        start: {AnsiblePipelineRunner, :start_link, []},
        # Explicitly set the :restart option because it is :permanent by
        # default, which is not supported in ConsumerSupervisor.
        restart: :transient
      }
    ]

    ConsumerSupervisor.init(children,
      strategy: :one_for_one,
      subscribe_to: [{AnsiblePipelineQueue.name(pipeline), min_demand: 3, max_demand: 5}]
    )
  end
end
