defmodule ArchiDep.Servers.ServerTracking.ServerManagerTest do
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServerManagerMock
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup %{test: test} do
    test_pid = self()

    state_factory = fn ->
      allow(ServerManagerMock, test_pid, self())
      ServerManagerMock
    end

    opts = [state: state_factory]

    server = ServersFactory.build(:server)

    initialize_fn = fn actions -> initialize_server_manager(server, opts, test, actions) end

    {:ok, initialize: initialize_fn, pid: test_pid, server: server}
  end

  test "initialize a server manager", %{initialize: initialize} do
    initialize.([])
    refute_received _anything_else
  end

  test "cancel a timer when starting a server manager", %{
    initialize: initialize,
    pid: test_pid
  } do
    timer_ref = Process.send_after(self(), :timer, 5000)
    timer_remaining = Process.read_timer(timer_ref)
    assert is_integer(timer_remaining) and timer_remaining > 4000

    expect(ServerManagerMock, :on_message, fn state, :done ->
      send(test_pid, :done)
      state
    end)

    initialize.([cancel_timer(timer_ref), send_message(:done)])

    assert_receive :done, 1000
    refute_received _anything_else

    assert Process.read_timer(timer_ref) == false
  end

  defp initialize_server_manager(server, opts, pipeline, actions) do
    id = server.id
    test_pid = self()

    expect(ServerManagerMock, :init, fn ^id, ^pipeline ->
      send(test_pid, :initialized)

      %ServerManagerState{
        server: server,
        pipeline: pipeline,
        username: "alice",
        actions: actions
      }
    end)

    start_supervised!(%{
      id: ServerManager,
      start: {ServerManager, :start_link, [id, pipeline, opts]}
    })

    assert_receive :initialized
  end

  defp cancel_timer(ref), do: {:cancel_timer, ref}

  defp send_message(message, ms \\ 0),
    do:
      {:send_message,
       fn state, factory ->
         factory.(message, ms)
         state
       end}
end
