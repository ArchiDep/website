defmodule ArchiDep.Events.Types do
  @moduledoc """
  Type definitions for the business events context.
  """

  alias ArchiDep.Events.Store.StoredEvent

  @type fetch_latest_events_option :: {:before, StoredEvent.t(any)} | {:limit, 1..1000}
end
