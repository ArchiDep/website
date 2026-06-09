defmodule ArchiDep.Clock.Behaviour do
  @moduledoc """
  Behaviour of the clock used to obtain the current time.

  The clock is injected (resolved through `ArchiDep.Clock`) rather than calling
  `DateTime.utc_now/0` directly so that tests can pin the current time and
  assert exact timestamps. See the testing guide in `docs/testing.md`.
  """

  @callback now() :: DateTime.t()
end
