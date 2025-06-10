defmodule ArchiDep.Tracker do
  use Phoenix.Tracker

  def start_link(opts) do
    Phoenix.Tracker.start_link(__MODULE__, [],
      name: __MODULE__,
      pubsub_server: Keyword.fetch!(opts, :pubsub_server)
    )
  end

  @impl true
  def init([]) do
    {:ok, nil}
  end

  @impl true
  def handle_diff(diff, state) do
    for {topic, {joins, leaves}} <- diff do
      for {key, meta} <- joins do
        IO.puts("presence join #{topic}: key \"#{key}\" with meta #{inspect(meta)}")
      end

      for {key, meta} <- leaves do
        IO.puts("presence leave #{topic}: key \"#{key}\" with meta #{inspect(meta)}")
      end
    end

    {:ok, state}
  end
end
