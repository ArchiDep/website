defmodule ArchiDep.Events.Policy do
  @moduledoc """
  Authorization policy for event-related actions.
  """

  use ArchiDep, :policy

  @impl Policy

  # Root users can perform any action.
  def authorize(
        :events,
        _action,
        %Authentication{root: true},
        _params
      ),
      do: true

  def authorize(_context, _action, _auth, _params), do: false
end
