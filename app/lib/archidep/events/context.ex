defmodule ArchiDep.Events.Context do
  @moduledoc false

  use ArchiDep, :context_impl

  @behaviour ArchiDep.Events.Behaviour

  alias ArchiDep.Events.Behaviour
  alias ArchiDep.Events.UseCases

  implement(&Behaviour.fetch_events/2, UseCases.FetchEvents)
end
