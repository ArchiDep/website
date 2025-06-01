defprotocol ArchiDep.Events.Store.Event do
  @moduledoc """
  A protocol for defining events in the ArchiDep system.
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
