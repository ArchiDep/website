defmodule ArchiDep.Events do
  @moduledoc """
  Events context, which handles event sourcing and event storage.
  """

  @behaviour ArchiDep.Events.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Events.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  delegate(&Behaviour.fetch_events/2)
end
