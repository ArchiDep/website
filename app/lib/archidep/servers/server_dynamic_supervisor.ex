defmodule ArchiDep.Servers.ServerDynamicSupervisor do
  use DynamicSupervisor

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerSupervisor

  @spec start_server_supervisor(Server.t()) :: DynamicSupervisor.on_start_child()
  def start_server_supervisor(server),
    do: DynamicSupervisor.start_child(__MODULE__, {ServerSupervisor, server})

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
