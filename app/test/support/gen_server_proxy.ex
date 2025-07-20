defmodule ArchiDep.Support.GenServerProxy do
  @moduledoc """
  A `GenServer` simulator that forwards all calls, casts and messages to a
  target process, allowing a test to act as another process.
  """

  use GenServer

  @spec start_link(pid(), GenServer.name()) :: GenServer.on_start()
  def start_link(target_pid, name),
    do: GenServer.start_link(__MODULE__, {target_pid, name}, name: name)

  @impl GenServer
  def init({target_pid, name}) do
    {:ok, {target_pid, name}}
  end

  @impl GenServer
  def handle_call(request, from, {target_pid, name} = state) do
    send(target_pid, {:proxy, name, {:call, request, from}})
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(request, {target_pid, name} = state) do
    send(target_pid, {:proxy, name, {:cast, request}})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, {target_pid, name} = state) do
    send(target_pid, {:proxy, name, {:info, msg}})
    {:noreply, state}
  end
end
