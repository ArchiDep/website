defmodule ArchiDep.Servers.ServerTracking.ServerSupervisor do
  @moduledoc """
  Supervisor responsible for running everything related to a specific server.
  """

  use Supervisor

  import ArchiDep.Servers.Helpers
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias Ecto.UUID

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id), do: {:global, {:server_supervisor, server_id}}

  @spec start_link(UUID.t(), Pipeline.t()) :: Supervisor.on_start()
  def start_link(server_id, pipeline),
    do: Supervisor.start_link(__MODULE__, {server_id, pipeline}, name: name(server_id))

  @impl Supervisor
  def init({server_id, pipeline}) do
    set_process_label(__MODULE__, server_id)

    children = [
      # The server manager is responsible for keeping track of the server's
      # state, performing actions like connecting, running commands, etc.
      {ArchiDep.Servers.ServerTracking.ServerManager,
       {server_id, pipeline, state: fn -> ServerManagerState end}},
      # The server connection handles the actual SSH connection to the server.
      # It may crash at any time and the manager will handle reconnections.
      {ArchiDep.Servers.ServerTracking.ServerConnection, server_id}
    ]

    Supervisor.init(children, auto_shutdown: :all_significant, strategy: :rest_for_one)
  end
end
