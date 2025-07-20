defmodule ArchiDep.Support.NoOpGenServer do
  @moduledoc """
  A no-op `GenServer` that does nothing.
  """

  use GenServer

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args), do: GenServer.start_link(__MODULE__, nil)

  @impl GenServer
  def init(nil), do: {:ok, nil}
end
