defmodule ArchiDep.Servers.ServerDynamicSupervisor do
  use DynamicSupervisor

  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.ServerSupervisor
  alias Ecto.UUID

  @name {:global, __MODULE__}

  @spec start_server_supervisor(UUID.t(), Pipeline.t()) :: DynamicSupervisor.on_start_child()
  def start_server_supervisor(server_id, pipeline),
    do: DynamicSupervisor.start_child(@name, {ServerSupervisor, {server_id, pipeline}})

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_init_arg),
    do: DynamicSupervisor.start_link(__MODULE__, nil, name: @name)

  @impl true
  def init(nil) do
    set_process_label(__MODULE__)
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
