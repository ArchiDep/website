defmodule ArchiDep.Events.Types do
  @moduledoc """
  Type definitions for the business events context.
  """

  alias ArchiDep.Events.Store.StoredEvent

  @type fetch_events_option ::
          {:newer_than, StoredEvent.t(any)}
          | {:older_than, StoredEvent.t(any)}
          | {:limit, 1..1000}
end
