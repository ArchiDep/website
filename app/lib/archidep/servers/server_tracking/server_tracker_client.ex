defmodule ArchiDep.Servers.ServerTracking.ServerTrackerClient do
  @moduledoc """
  Access to the client API of
  `ArchiDep.Servers.ServerTracking.ServerTracker` through an injectable
  implementation.

  The web layer starts trackers and reads server states through this module
  instead of calling the GenServer directly. In production it delegates to
  `ServerTracker`; in the test environment it is configured to a mock so that
  LiveViews can be tested in isolation.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerTrackerClientBehaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate start_link(servers), to: @implementation
  defdelegate track(tracker, server), to: @implementation
  defdelegate untrack(tracker, server), to: @implementation
  defdelegate server_state_map(servers), to: @implementation
  defdelegate update_server_state_map(map, update), to: @implementation
  defdelegate get_current_server_state(server), to: @implementation
end
