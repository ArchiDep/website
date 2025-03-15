defmodule ArchiDep.Events.Store.Registry.Utils do
  @moduledoc """
  Utilities for event registries.
  """

  alias ArchiDep.Events.Store.StoredEvent

  @doc """
  Deserialized a stored event's data into the correct struct.
  """
  @spec deserialize(module, StoredEvent.t(struct)) :: struct
  def deserialize(registry, %StoredEvent{data: data, type: type}) do
    registry.deserialize(data, type)
  end
end
