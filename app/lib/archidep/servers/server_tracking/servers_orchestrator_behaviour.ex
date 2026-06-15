defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorBehaviour do
  @moduledoc """
  Behaviour of the client API of
  `ArchiDep.Servers.ServerTracking.ServersOrchestrator` that use cases rely on
  to ensure a server is being tracked before delegating an operation to its
  manager.

  It is implemented in production by the `ServersOrchestrator` GenServer and
  swapped for a mock in the test environment so that use cases can be tested in
  isolation.
  """

  alias ArchiDep.Servers.Schemas.Server

  @callback ensure_started(Server.t()) :: :ok | {:error, :server_not_found}
end
