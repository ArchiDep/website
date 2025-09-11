defprotocol ArchiDep.Events.Store.EventInitiator do
  @moduledoc """
  A protocol for defining initiator of events in the application. An initiator
  is an entity that causes an event to occur. It could be a user or a tracked
  server.
  """

  @type t :: struct

  @doc """
  Returns the stream that represents an initiator of events.
  """
  @spec event_initiator_stream(struct) :: String.t()
  def event_initiator_stream(initiator)
end
