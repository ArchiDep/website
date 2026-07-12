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
  alias ArchiDep.Servers.ServerView
  alias Ecto.UUID

  @typedoc "Anything the tracker can read a server ID from."
  @type trackable :: Server.t() | ServerView.t()

  @callback start_link(trackable() | list(trackable())) :: GenServer.on_start()

  @callback track(pid(), trackable()) :: ServerTracker.server_state_update()

  @callback untrack(pid(), trackable()) :: ServerTracker.server_state_update()

  @callback server_state_map(list(trackable())) :: %{
              optional(UUID.t()) => ServerRealTimeState.t()
            }

  @callback update_server_state_map(
              %{optional(UUID.t()) => ServerRealTimeState.t() | nil},
              ServerTracker.server_state_update()
            ) :: %{optional(UUID.t()) => ServerRealTimeState.t() | nil}

  @callback get_current_server_state(trackable() | UUID.t()) :: ServerRealTimeState.t() | nil
end
