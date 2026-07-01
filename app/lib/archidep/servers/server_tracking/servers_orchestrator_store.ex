defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorStore do
  @moduledoc """
  Default store for `ArchiDep.Servers.ServerTracking.ServersOrchestrator`. Reads
  the servers that should currently be tracked, deciding activeness relative to
  the current system time.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreBehaviour

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreBehaviour
  alias Ecto.UUID

  @impl ServersOrchestratorStoreBehaviour
  @spec list_servers_to_track() :: [Server.t()]
  def list_servers_to_track, do: Server.list_active_servers(DateTime.utc_now())

  @impl ServersOrchestratorStoreBehaviour
  @spec fetch_server_to_track(UUID.t()) :: {:ok, Server.t()} | :not_tracked
  def fetch_server_to_track(server_id) do
    with {:ok, server} <- Server.fetch_server(server_id),
         true <- Server.active?(server, DateTime.utc_now()) do
      {:ok, server}
    else
      {:error, :server_not_found} -> :not_tracked
      false -> :not_tracked
    end
  end
end
