defmodule ArchiDep.Servers.Supervisor do
  @moduledoc """
  Supervisor for the servers context.
  """

  use Supervisor

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_init_arg), do: Supervisor.start_link(__MODULE__, nil, name: __MODULE__)

  @impl Supervisor
  def init(nil) do
    children = [
      {ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineSupervisor,
       ArchiDep.Servers.Ansible.Pipeline},
      ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor,
      {ArchiDep.Servers.ServerTracking.ServersOrchestrator, ArchiDep.Servers.Ansible.Pipeline}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
