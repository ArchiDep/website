defprotocol ArchiDep.Events.Store.Event do
  @moduledoc """
  A protocol for defining events in the application. An event is a record of
  something that has happened in the system, which can be used for logging,
  auditing, or triggering other actions.

  Events are grouped into streams, and each event has a type that describes what
  kind of event it is.
  """

  @doc """
  Returns the stream an event is part of.
  """
  @spec event_stream(struct) :: String.t()
  def event_stream(event)

  @doc """
  Returns the type of an event.
  """
  @spec event_type(term) :: atom
  def event_type(event)
end
