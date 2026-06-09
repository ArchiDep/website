defmodule ArchiDep.Clock do
  @moduledoc """
  Access to the current time through an injectable implementation.

  Business logic should obtain the current time from this module instead of
  calling `DateTime.utc_now/0` directly. In production it delegates to
  `ArchiDep.Clock.SystemClock`; in the test environment it is configured to a
  mock so that each test can pin the clock and assert exact timestamps. See the
  testing guide in `docs/testing.md`.
  """

  @behaviour ArchiDep.Clock.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate now, to: @implementation
end
