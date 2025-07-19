defmodule ArchiDep.Tracker do
  @moduledoc """
  Presence tracking for the application.
  """

  use Phoenix.Tracker

  alias Phoenix.PubSub
  alias Phoenix.Tracker

  @pubsub ArchiDep.PubSub

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts),
    do:
      Phoenix.Tracker.start_link(__MODULE__, [],
        name: __MODULE__,
        pubsub_server: Keyword.fetch!(opts, :pubsub_server)
      )

  @impl Tracker
  def init([]), do: {:ok, nil}

  @impl Tracker
  def handle_diff(diff, state) do
    for {topic, {joins, leaves}} <- diff do
      # Merge leave-pairs for the same key into updates.
      (Enum.map(leaves, &{:leave, &1}) ++ Enum.map(joins, &{:join, &1}))
      |> Enum.reduce(%{}, fn {action, {key, meta}}, acc ->
        Map.update(acc, key, {action, meta}, fn _existing_meta -> {:update, meta} end)
      end)
      # Broadcast joins, updates and leaves.
      |> Enum.each(fn {key, {action, meta}} ->
        PubSub.local_broadcast(@pubsub, "tracker:#{topic}", {action, key, meta})
      end)
    end

    {:ok, state}
  end
end
