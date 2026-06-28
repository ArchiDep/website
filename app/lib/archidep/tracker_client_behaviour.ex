defmodule ArchiDep.TrackerClientBehaviour do
  @moduledoc """
  Behaviour of the client API of `ArchiDep.Tracker` that the web layer relies on
  to read the current presence list of a tracked topic.

  It is implemented in production by the `ArchiDep.Tracker` `Phoenix.Tracker`
  and swapped for a mock in the test environment so that LiveViews can be tested
  in isolation.
  """

  @callback list(topic :: String.t()) :: [{term(), map()}]
end
