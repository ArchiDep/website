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
  end
end
