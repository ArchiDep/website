defmodule ArchiDep.Servers.ServerManager do
  use GenServer

  require Logger
  alias ArchiDep.Servers.Schemas.Server

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: {:global, {:server, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server manager for server #{server_id}")
    {:ok, server_id}
  end
end
