defmodule ArchiDep.Servers.ServerSupervisor do
  @moduledoc """
  Supervisor responsible for running everything related to a specific server.
  """

  use Supervisor

  alias ArchiDep.Servers.Schemas.Server

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: {:global, {:server_supervisor, server_id}}

  @spec start_link(Server.t()) :: Supervisor.on_start()
  def start_link(server) do
    Supervisor.start_link(__MODULE__, server, name: __MODULE__)
  end

  @impl true
  def init(server) do
    children = [
      {ArchiDep.Servers.ServerManager, server},
      {ArchiDep.Servers.ServerConnection, server}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
