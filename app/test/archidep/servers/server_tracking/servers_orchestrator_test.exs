defmodule ArchiDep.Servers.ServerTracking.ServersOrchestratorTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.ServerTracking.ServersOrchestrator
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorStoreMock
  alias ArchiDep.Servers.ServerTracking.ServerSupervisorStarterMock
  alias ArchiDep.Support.NoOpGenServer
  alias ArchiDep.Support.ServersFactory

  @pipeline Pipeline

  setup :verify_on_exit!

  setup %{test: test} do
    test_pid = self()

    # The collaborators factory runs inside the orchestrator process (in
    # `init`), so it allows the owner-scoped mocks onto that process before
    # `handle_continue`/`handle_info` use them — the `server_manager_test`
    # injection idiom, which keeps this test `async: true`.
    collaborators = fn ->
      allow(ServersOrchestratorStoreMock, test_pid, self())
      allow(ServerSupervisorStarterMock, test_pid, self())
      # The orchestrator subscribes to a scoped topic in `handle_continue`, so
      # it needs the per-test PubSub scope stub `DataCase` set on the test
      # process.
      allow(ArchiDep.PubSub.Scope.Mock, test_pid, self())
      {ServersOrchestratorStoreMock, ServerSupervisorStarterMock}
    end

    %{name: {:global, {ServersOrchestrator, test}}, collaborators: collaborators}
  end

  test "starts a supervisor for each server to track on boot", %{
    name: name,
    collaborators: collaborators
  } do
    test_pid = self()
    server1 = ServersFactory.build(:server)
    server2 = ServersFactory.build(:server)

    expect(ServersOrchestratorStoreMock, :list_servers_to_track, fn -> [server1, server2] end)

    expect(ServerSupervisorStarterMock, :start_server_supervisor, 2, fn server_id, @pipeline ->
      send(test_pid, {:started, server_id})
      {:ok, self()}
    end)

    start_orchestrator!(name, collaborators, track_on_boot: true)

    assert_receive {:started, first}
    assert_receive {:started, second}
    assert [first, second] == [server1.id, server2.id]
  end

  test "starts nothing on boot when tracking is disabled", %{
    name: name,
    collaborators: collaborators
  } do
    start_orchestrator!(name, collaborators, track_on_boot: false)

    refute_received {:started, _server_id}
  end

  test "starts a supervisor when a created server is active", %{
    name: name,
    collaborators: collaborators
  } do
    test_pid = self()
    server = ServersFactory.build(:server)
    server_id = server.id

    expect(ServersOrchestratorStoreMock, :list_servers_to_track, fn -> [] end)
    pid = start_orchestrator!(name, collaborators, track_on_boot: true)
    # Ensure `handle_continue` (which subscribes) ran before we publish.
    _subscribed = :sys.get_state(pid)

    expect(ServersOrchestratorStoreMock, :fetch_server_to_track, fn ^server_id ->
      {:ok, server}
    end)

    expect(ServerSupervisorStarterMock, :start_server_supervisor, fn ^server_id, @pipeline ->
      send(test_pid, {:started, server_id})
      {:ok, self()}
    end)

    :ok = PubSub.publish_server_created(server)

    assert_receive {:started, ^server_id}
  end

  test "starts nothing when a created server is not active", %{
    name: name,
    collaborators: collaborators
  } do
    test_pid = self()
    server = ServersFactory.build(:server)
    server_id = server.id

    expect(ServersOrchestratorStoreMock, :list_servers_to_track, fn -> [] end)
    pid = start_orchestrator!(name, collaborators, track_on_boot: true)
    # Ensure `handle_continue` (which subscribes) ran before we publish.
    _subscribed = :sys.get_state(pid)

    expect(ServersOrchestratorStoreMock, :fetch_server_to_track, fn ^server_id ->
      send(test_pid, {:fetched, server_id})
      :not_tracked
    end)

    :ok = PubSub.publish_server_created(server)

    # The fetch runs first in `handle_info`; once it has, a `:not_tracked` result
    # means no supervisor is ever started.
    assert_receive {:fetched, ^server_id}
    refute_received {:started, _server_id}
  end

  test "ensure_started dispatches to the starter and replies with its result", %{
    name: name,
    collaborators: collaborators
  } do
    server = ServersFactory.build(:server)
    server_id = server.id
    supervisor = start_supervised!(NoOpGenServer)

    start_orchestrator!(name, collaborators, track_on_boot: false)

    expect(ServerSupervisorStarterMock, :start_server_supervisor, fn ^server_id, @pipeline ->
      {:ok, supervisor}
    end)

    assert GenServer.call(name, {:ensure_started, server_id}) == {:ok, supervisor}
  end

  describe "map_start_result/1" do
    test "maps a freshly started supervisor to :ok" do
      assert ServersOrchestrator.map_start_result({:ok, self()}) == :ok
    end

    test "maps an already-started supervisor to :ok" do
      assert ServersOrchestrator.map_start_result({:error, {:already_started, self()}}) == :ok
    end
  end

  defp start_orchestrator!(name, collaborators, opts),
    do:
      start_supervised!(%{
        id: ServersOrchestrator,
        start:
          {ServersOrchestrator, :start_link,
           [@pipeline, [name: name, collaborators: collaborators] ++ opts]}
      })
end
