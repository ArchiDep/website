defmodule ArchiDep.PubSub.Scope.GlobalScope do
  @moduledoc """
  Default `ArchiDep.PubSub.Scope` implementation that applies no suffix, so
  global topics keep their shared names across the whole node.
  """

  @behaviour ArchiDep.PubSub.Scope.Behaviour

  @impl ArchiDep.PubSub.Scope.Behaviour
  def suffix, do: ""
end
