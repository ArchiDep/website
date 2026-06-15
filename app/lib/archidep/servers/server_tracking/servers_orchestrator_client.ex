defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorClient do
  @moduledoc """
  Access to the client API of
  `ArchiDep.Servers.ServerTracking.ServersOrchestrator` through an injectable
  implementation.

  Use cases call the orchestrator through this module instead of calling the
  GenServer directly. In production it delegates to `ServersOrchestrator`; in
  the test environment it is configured to a mock so that each use case can be
  tested in isolation.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServersOrchestratorBehaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate ensure_started(server), to: @implementation
end
