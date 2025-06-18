defmodule ArchiDep.Servers.ServerSupervisor do
  @moduledoc """
  Supervisor responsible for running everything related to a specific server.
  """

  use Supervisor

  import ArchiDep.Servers.Helpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.Server

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id), do: {:global, {:server_supervisor, server_id}}

  @spec start_link({UUID.t(), Pipeline.t()}) :: Supervisor.on_start()
  def start_link({server_id, pipeline}) do
    Supervisor.start_link(__MODULE__, {server_id, pipeline}, name: name(server_id))
  end

  @impl true
  def init({server_id, pipeline}) do
    set_process_label(__MODULE__, server_id)

    children = [
      {ArchiDep.Servers.ServerManager, {server_id, pipeline}},
      {ArchiDep.Servers.ServerConnection, server_id}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
