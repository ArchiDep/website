defmodule ArchiDep.Events.Behaviour do
  @moduledoc false

  use ArchiDep, :context_behaviour

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
