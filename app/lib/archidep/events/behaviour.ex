defmodule ArchiDep.Events.Behaviour do
  @moduledoc """
  Specification of the events context.
  """

  use ArchiDep.Helpers.ContextHelpers, :behaviour

  import ArchiDep.Helpers.ContextHelpers, only: [callback: 1]
  alias ArchiDep.Authentication
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
