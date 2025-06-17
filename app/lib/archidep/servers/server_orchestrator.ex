defmodule ArchiDep.Servers.ServerOrchestrator do
  @moduledoc """
  GenServer responsible for tracking which servers should be active and tracked,
  and which servers should be disconnected.
  """

  use GenServer

  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerDynamicSupervisor

  @name {:global, __MODULE__}

  # Client API

  @spec start_link(Pipeline.t()) :: GenServer.on_start()
  def start_link(pipeline),
    do: GenServer.start_link(__MODULE__, pipeline, name: @name)

  # Server callbacks

  @impl true
  def init(pipeline) do
    set_process_label(__MODULE__)
    {:ok, pipeline, {:continue, :load_servers}}
  end

  @impl true
  def handle_continue(:load_servers, pipeline) do
    for server <- Server.list_active_servers() do
      {:ok, _pid} = ServerDynamicSupervisor.start_server_supervisor(server, pipeline)
    end

    {:noreply, pipeline}
  end
end
