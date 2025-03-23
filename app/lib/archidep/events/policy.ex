defmodule ArchiDep.Events.Policy do
  @moduledoc """
  Authorization rules for the events context.
  """

  use ArchiDep, :policy

  @impl Policy

  def authorize(
        :events,
        :fetch_latest_events,
        %Authentication{principal: %UserAccount{roles: roles}},
        nil
      ),
      do: Enum.member?(roles, :root)

  def authorize(_action, _principal, _params), do: false
end
