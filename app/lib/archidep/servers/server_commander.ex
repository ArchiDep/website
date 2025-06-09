defmodule ArchiDep.Servers.ServerCommander do
  @moduledoc """
  GenServer responsible for tracking which servers should be active and tracked,
  and which servers should be disconnected.
  """

  use GenServer

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManagerSupervisor

  @name {:global, __MODULE__}

  # Client API

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_init_arg),
    do: GenServer.start_link(__MODULE__, nil, name: @name)

  # Server callbacks

  @impl true
  def init(nil) do
    {:ok, nil, {:continue, :load_servers}}
  end

  @impl true
  def handle_continue(:load_servers, nil) do
    for server <- Server.list_active_servers() do
      {:ok, _pid} = ServerManagerSupervisor.start_server_manager(server)
    end

    {:noreply, nil}
  end
end
