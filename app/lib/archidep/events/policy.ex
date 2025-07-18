defmodule ArchiDep.Events.Policy do
  @moduledoc """
  Authorization policy for event-related actions.
  """

  use ArchiDep, :policy

  @impl Policy

  def authorize(
        :events,
        :fetch_events,
        %Authentication{roles: roles},
        nil
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
