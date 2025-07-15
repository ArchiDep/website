defmodule ArchiDep.Events.Context do
  @moduledoc false

  use ArchiDep, :context_impl

  @behaviour ArchiDep.Events.Behaviour

  alias ArchiDep.Events.Behaviour

  implement(&Behaviour.fetch_events/2, ArchiDep.Events.FetchEvents)
end
