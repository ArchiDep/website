defmodule ArchiDep.Events do
  @moduledoc """
  Events context, which handles event sourcing and event storage.
  """

  use ArchiDep, :context

  @behaviour ArchiDep.Events.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  alias ArchiDep.Events.Behaviour

  delegate(&Behaviour.fetch_events/2)
end
