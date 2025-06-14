defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineConsumer do
  use ConsumerSupervisor

  require Logger
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
