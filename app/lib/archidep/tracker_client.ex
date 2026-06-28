defmodule ArchiDep.TrackerClient do
  @moduledoc """
  Access to the client API of `ArchiDep.Tracker` through an injectable
  implementation.

  The web layer reads the presence list of a tracked topic through this module
  instead of calling the tracker directly. In production it delegates to
  `ArchiDep.Tracker`; in the test environment it is configured to a mock so that
  LiveViews can be tested in isolation.
  """

  @behaviour ArchiDep.TrackerClientBehaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate list(topic), to: @implementation
end
