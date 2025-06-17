defmodule ArchiDep.Tracker do
  use Phoenix.Tracker

  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts),
    do:
      Phoenix.Tracker.start_link(__MODULE__, [],
        name: __MODULE__,
        pubsub_server: Keyword.fetch!(opts, :pubsub_server)
      )

  @impl true
  def init([]), do: {:ok, nil}

  @impl true
  def handle_diff(diff, state) do
    for {topic, {joins, leaves}} <- diff do
      (Enum.map(leaves, &{:leave, &1}) ++ Enum.map(joins, &{:join, &1}))
      |> Enum.reduce(%{}, fn {action, {key, meta}}, acc ->
        Map.update(acc, key, {action, meta}, fn _existing_meta -> {:update, meta} end)
      end)
      |> Enum.each(fn {key, {action, meta}} ->
        IO.puts("presence #{action} #{topic}: key \"#{key}\" with meta #{inspect(meta)}")
        PubSub.local_broadcast(@pubsub, "tracker:#{topic}", {action, key, meta})
      end)
    end

    {:ok, state}
  end
end
