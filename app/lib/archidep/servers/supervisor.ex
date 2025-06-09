defmodule ArchiDep.Servers.Supervisor do
  @moduledoc """
  Supervisor for the servers context.
  """

  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    children = [
      ArchiDep.Servers.ServerManagerSupervisor,
      ArchiDep.Servers.ServerOrchestrator
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
