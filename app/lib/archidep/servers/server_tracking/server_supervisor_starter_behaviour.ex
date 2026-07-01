defmodule ArchiDep.Servers.ServerTracking.ServerSupervisorStarterBehaviour do
  @moduledoc """
  Behaviour of the collaborator used by
  `ArchiDep.Servers.ServerTracking.ServersOrchestrator` to start the supervisor
  of an individual server.

  It is injected into the orchestrator at `start_link/2` (defaulting to
  `ArchiDep.Servers.ServerTracking.ServerDynamicSupervisor`) rather than
  resolved through a compile-time configuration, because the call happens inside
  the spawned orchestrator process — before a test can allow it onto its mocks —
  and because starting a real per-server supervisor spins up processes that
  connect to the server.
  """

  alias ArchiDep.Servers.Ansible.Pipeline
  alias Ecto.UUID

  @callback start_server_supervisor(UUID.t(), Pipeline.t()) ::
              DynamicSupervisor.on_start_child()
end
