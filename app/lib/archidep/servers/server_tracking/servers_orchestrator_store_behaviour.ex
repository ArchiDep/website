defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreBehaviour do
  @moduledoc """
  Behaviour of the store used by
  `ArchiDep.Servers.ServerTracking.ServersOrchestrator` for the database reads
  it performs when deciding which servers to track.

  It is injected into the orchestrator at `start_link/2` (defaulting to
  `ArchiDep.Servers.ServerTracking.ServersOrchestratorStore`) rather than
  resolved through a compile-time configuration, because the reads happen in
  `handle_continue/2` and `handle_info/2` — before a test can allow the spawned
  orchestrator process onto its mocks — so a test injects a stand-in instead.
  The store also owns the current time (a server is active relative to "now"),
  which keeps the orchestrator itself free of any clock or database dependency.
  """

  alias ArchiDep.Servers.Schemas.Server
  alias Ecto.UUID

  @callback list_servers_to_track() :: [Server.t()]

  @callback fetch_server_to_track(UUID.t()) :: {:ok, Server.t()} | :not_tracked
end
