defmodule ArchiDep.Servers.ServerTracking.ServerTrackerClientBehaviour do
  @moduledoc """
  Behaviour of the client API of `ArchiDep.Servers.ServerTracking.ServerTracker`
  that the web layer relies on to start a tracker and read the real-time state
  of servers.

  It is implemented in production by the `ServerTracker` GenServer and swapped
  for a mock in the test environment so that LiveViews can be tested in
  isolation.
  """

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias Ecto.UUID

  @callback start_link(Server.t() | list(Server.t())) :: GenServer.on_start()

  @callback track(pid(), Server.t()) :: ServerTracker.server_state_update()

  @callback untrack(pid(), Server.t()) :: ServerTracker.server_state_update()

  @callback server_state_map(list(Server.t())) :: %{UUID.t() => ServerRealTimeState.t()}

  @callback update_server_state_map(
              %{UUID.t() => ServerRealTimeState.t()},
              ServerTracker.server_state_update()
            ) :: %{UUID.t() => ServerRealTimeState.t()}

  @callback get_current_server_state(Server.t() | UUID.t()) :: ServerRealTimeState.t() | nil
end
