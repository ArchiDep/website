defmodule ArchiDep.Servers.Supervisor do
  @moduledoc """
  Supervisor for the servers context.
  """

  use Supervisor

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_init_arg), do: Supervisor.start_link(__MODULE__, nil, name: __MODULE__)

  @impl Supervisor
  def init(nil) do
    track_on_boot = Application.fetch_env!(:archidep, :servers)[:track_on_boot]

    children = [
      {ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineSupervisor,
       ArchiDep.Servers.Ansible.Pipeline},
      ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor,
      %{
        id: ArchiDep.Servers.ServerTracking.ServersOrchestrator,
        start:
          {ArchiDep.Servers.ServerTracking.ServersOrchestrator, :start_link,
           [ArchiDep.Servers.Ansible.Pipeline, [track_on_boot: track_on_boot]]}
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
