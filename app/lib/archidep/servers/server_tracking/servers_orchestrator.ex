defmodule ArchiDep.Servers.ServerTracking.ServersOrchestrator do
  @moduledoc """
  GenServer responsible for tracking which servers should be active and tracked,
  and running their supervisors.

  Its side effects — reading which servers to track (and when a server is
  active) and starting per-server supervisors — are performed through
  collaborators injected at `start_link/2`, so the orchestrator itself holds no
  database, clock or supervision logic and can be driven in isolation.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServersOrchestratorBehaviour

  use GenServer

  import ArchiDep.Helpers.ProcessHelpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorBehaviour
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorStore
  require Logger

  @name {:global, __MODULE__}

  defmodule State do
    @moduledoc false

    alias ArchiDep.Servers.Ansible.Pipeline

    @enforce_keys [:pipeline, :store, :starter, :track_on_boot]
    defstruct [:pipeline, :store, :starter, :track_on_boot]

    @type t :: %__MODULE__{
            pipeline: Pipeline.t(),
            store: module(),
            starter: module(),
            track_on_boot: boolean()
          }
  end

  @type start_option ::
          {:name, GenServer.name()}
          | {:track_on_boot, boolean()}
          | {:collaborators, (-> {module(), module()})}

  @spec start_link(Pipeline.t(), [start_option()]) :: GenServer.on_start()
  def start_link(pipeline, opts \\ []),
    do: GenServer.start_link(__MODULE__, {pipeline, opts}, name: Keyword.get(opts, :name, @name))

  # Client API

  @impl ServersOrchestratorBehaviour
  @spec ensure_started(Server.t()) ::
          :ok | {:error, :server_not_found}
  def ensure_started(server),
    do: @name |> GenServer.call({:ensure_started, server.id}) |> map_start_result()

  @spec map_start_result({:ok, pid()} | {:error, {:already_started, pid()}}) :: :ok
  def map_start_result({:ok, _pid}), do: :ok
  def map_start_result({:error, {:already_started, _pid}}), do: :ok

  # Server callbacks

  @impl GenServer
  def init({pipeline, opts}) do
    {store, starter} = Keyword.get(opts, :collaborators, &default_collaborators/0).()

    state = %State{
      pipeline: pipeline,
      store: store,
      starter: starter,
      track_on_boot: Keyword.get(opts, :track_on_boot, false)
    }

    {:ok, state, {:continue, :load_servers}}
  end

  @impl GenServer
  def handle_continue(:load_servers, %State{} = state) do
    set_process_label(__MODULE__)

    # Only a node that tracks servers reacts to newly created ones; when
    # tracking is disabled (e.g. in the test environment) the orchestrator stays
    # inert and does not subscribe, so a `server_created` broadcast never wakes
    # it to query the database outside of any caller's transaction.
    if state.track_on_boot do
      :ok = PubSub.subscribe_server_created()

      servers_to_track = state.store.list_servers_to_track()
      Logger.notice("Tracking #{length(servers_to_track)} active server(s)")

      for server <- servers_to_track do
        {:ok, _pid} = state.starter.start_server_supervisor(server.id, state.pipeline)
      end
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:ensure_started, server_id}, _from, %State{} = state) do
    result = state.starter.start_server_supervisor(server_id, state.pipeline)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_info({:server_created, created_server}, %State{} = state) do
    case state.store.fetch_server_to_track(created_server.id) do
      {:ok, server} ->
        {:ok, _pid} = state.starter.start_server_supervisor(server.id, state.pipeline)

      :not_tracked ->
        :ok
    end

    {:noreply, state}
  end

  defp default_collaborators, do: {ServersOrchestratorStore, ServerDynamicSupervisor}
end
