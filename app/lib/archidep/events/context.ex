defmodule ArchiDep.Events.Context do
  @moduledoc false

  import ArchiDep.Helpers.ContextHelpers, only: [implement: 2]
  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.FetchEvents

  @behaviour ArchiDep.Events.Behaviour

  implement(&Behaviour.fetch_events/2, FetchEvents)
end
