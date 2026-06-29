defmodule ArchiDep.PubSub.Scope.Behaviour do
  @moduledoc """
  Behaviour of the PubSub topic scope used to suffix global topics.

  The scope is injected (resolved through `ArchiDep.PubSub.Scope`) so that the
  test environment can isolate global topics per test and assert exact broadcast
  outcomes. See the testing guide in `docs/testing.md`.
  """

  @callback suffix() :: String.t()
end
