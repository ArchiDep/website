defmodule ArchiDep.Events do
  @moduledoc """
  Business events context.
  """

  @behaviour ArchiDep.Events.Behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [delegate: 1]
  alias ArchiDep.Events.Behaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  delegate(&Behaviour.fetch_events/2)
end
