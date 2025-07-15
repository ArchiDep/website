defmodule ArchiDep.Events.Behaviour do
  @moduledoc """
  Specification for the events context, which handles event sourcing and event
  storage.
  """

  use ArchiDep, :behaviour

  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Events.Types

  @doc """
  Returns the latest stored events.
  """
  callback(
    fetch_events(
      auth: Authentication.t(),
      opts: list(Types.fetch_events_option())
    ) ::
      list(StoredEvent.t(map))
  )
end
