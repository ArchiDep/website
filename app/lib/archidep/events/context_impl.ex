defmodule ArchiDep.Events.ContextImpl do
  @moduledoc false

  @behaviour ArchiDep.Events.Behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [implement: 2]
  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.FetchLatestEvents

  implement(&Behaviour.fetch_latest_events/2, FetchLatestEvents)
end
