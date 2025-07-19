defmodule ArchiDep.Servers.ServerTracking.ServerOrchestrator do
  @moduledoc """
  GenServer responsible for tracking which servers should be active and tracked,
  and running their supervisors.
  """

  use GenServer

  require Logger
  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor

  @name {:global, __MODULE__}
  @track_on_boot Application.compile_env!(:archidep, [:servers, :track_on_boot])

  @spec start_link(Pipeline.t()) :: GenServer.on_start()
  def start_link(pipeline),
    do: GenServer.start_link(__MODULE__, pipeline, name: @name)

  # Client API

  @spec ensure_started(Server.t()) ::
          :ok | {:error, :server_not_found}
  def ensure_started(server) do
    case GenServer.call(@name, {:ensure_started, server.id}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  # Server callbacks

  @impl GenServer
  def init(pipeline), do: {:ok, pipeline, {:continue, :load_servers}}

  @impl GenServer
  def handle_continue(:load_servers, pipeline) do
    set_process_label(__MODULE__)

    :ok = PubSub.subscribe_server_created()

    if @track_on_boot do
      active_servers = Server.list_active_servers(DateTime.utc_now())
      Logger.notice("Tracking #{length(active_servers)} active server(s)")

      for server <- active_servers do
        {:ok, _pid} = ServerDynamicSupervisor.start_server_supervisor(server.id, pipeline)
      end
    end

    {:noreply, pipeline}
  end

  @impl GenServer
  def handle_call({:ensure_started, server_id}, _from, pipeline) do
    result = ServerDynamicSupervisor.start_server_supervisor(server_id, pipeline)
    {:reply, result, pipeline}
  end

  @impl GenServer
  def handle_info({:server_created, created_server}, pipeline) do
    {:ok, server} = Server.fetch_server(created_server.id)

    if Server.active?(server, DateTime.utc_now()) do
      {:ok, _pid} = ServerDynamicSupervisor.start_server_supervisor(server.id, pipeline)
    end

    {:noreply, pipeline}
  end
end
