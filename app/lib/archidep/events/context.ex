defmodule ArchiDep.Events.Context do
  @moduledoc false

  @behaviour ArchiDep.Events.Behaviour

  use ArchiDep, :context_impl

  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.UseCases

  implement(&Behaviour.fetch_events/2, UseCases.FetchEvents)
  implement(&Behaviour.fetch_event/2, UseCases.FetchEvents)
end
