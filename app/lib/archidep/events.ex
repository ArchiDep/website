defmodule ArchiDep.Events do
  @moduledoc """
  Events context, which handles event sourcing and event storage.
  """

  @behaviour ArchiDep.Events.Behaviour

  use ArchiDep, :context

  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Events.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @doc """
  Returns the latest stored events.
  """
  @spec fetch_events(Authentication.t(), list(Types.fetch_events_option())) ::
          list(StoredEvent.t(map))
  defdelegate fetch_events(auth, opts), to: @implementation

  @doc """
  Returns a specific stored event.
  """
  @spec fetch_event(Authentication.t(), UUID.t()) ::
          {:ok, StoredEvent.t(map)} | {:error, :event_not_found}
  defdelegate fetch_event(auth, id), to: @implementation
end
