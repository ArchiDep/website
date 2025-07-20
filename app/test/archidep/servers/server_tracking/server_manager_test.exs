defmodule ArchiDep.Servers.ServerTracking.ServerManagerTest do
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServerManagerMock
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup do
    test_pid = self()

    state_factory = fn ->
      allow(ServerManagerMock, test_pid, self())
      ServerManagerMock
    end

    opts = [state: state_factory]

    {:ok, opts: opts, pid: test_pid}
  end

  test "start a server manager", %{opts: opts, pid: test_pid, test: test} do
    server = ServersFactory.build(:server)
    id = server.id

    expect(ServerManagerMock, :init, fn ^id, ^test ->
      send(test_pid, :initialized)
      %ServerManagerState{server: server, pipeline: test, username: "alice", actions: []}
    end)

    start_supervised!(%{id: ServerManager, start: {ServerManager, :start_link, [id, test, opts]}})

    assert_receive :initialized
    refute_received _anything_else
  end

  test "cancel a timer when starting a server manager", %{opts: opts, pid: test_pid, test: test} do
    server = ServersFactory.build(:server)
    id = server.id

    timer_ref = Process.send_after(self(), :timer, 5000)
    timer_remaining = Process.read_timer(timer_ref)
    assert is_integer(timer_remaining) and timer_remaining > 4000

    expect(ServerManagerMock, :init, fn ^id, ^test ->
      send(test_pid, :initialized)

      %ServerManagerState{
        server: server,
        pipeline: test,
        username: "alice",
        actions: [
          cancel_timer(timer_ref),
          {:retry_connecting,
           fn retry_state, retry_factory ->
             retry_factory.(0)
             retry_state
           end}
        ]
      }
    end)

    expect(ServerManagerMock, :retry_connecting, fn state, _manual ->
      send(test_pid, :retry_connecting)
      state
    end)

    start_supervised!(%{id: ServerManager, start: {ServerManager, :start_link, [id, test, opts]}})

    assert_receive :initialized
    assert_receive :retry_connecting, 1000
    refute_received _anything_else

    assert Process.read_timer(timer_ref) == false
  end

  defp cancel_timer(ref), do: {:cancel_timer, ref}
end
