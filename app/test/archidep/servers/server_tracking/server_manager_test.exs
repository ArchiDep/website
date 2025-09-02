defmodule ArchiDep.Servers.ServerTracking.ServerManagerTest do
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServerManagerMock
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.GenServerProxy
  alias ArchiDep.Support.NoOpGenServer
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

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
  end

  test "cancel a timer when starting a server manager", %{
    initialize: initialize,
    pid: test_pid
  } do
    # Start a timer to cancel before the end of this test.
    timer_ref = Process.send_after(self(), :timer, 5000)
    timer_remaining = Process.read_timer(timer_ref)
    assert is_integer(timer_remaining) and timer_remaining > 4000

    # Expect that the server manager will receive a done message at some point.
    # When it does, send a done message to the test process so that we know the
    # test is complete.
    expect(ServerManagerMock, :on_message, fn state, :done ->
      send(test_pid, :done)
      state
    end)

    # Initialize the server manager with a timer cancelation action and an
    # action that sends a done message.
    initialize.([cancel_timer(timer_ref), send_message(:done)])

    # Wait for the done message.
    assert_receive :done, 1000
    refute_received _anything_else

    # Ensure the timer has been canceled.
    assert Process.read_timer(timer_ref) == false
  end

  test "have a server manager open a connection to its server", %{
    initialize: initialize,
    server: server,
    test_pid: test_pid
  } do
    # Prepare the fake connection parameters.
    host = server.ip_address.address
    port = server.ssh_port || 22
    username = server.username
    server_conn = ServerConnection.name(server)

    # Start a fake server connection process that will forward all calls to the
    # test process.
    start_link_supervised!(%{
      id: ServerConnection,
      start: {GenServerProxy, :start_link, [self(), server_conn]}
    })

    # Expected the server manager to handle the connection task result at some
    # point. Forward the result to the test process when that happens.
    expect(ServerManagerMock, :handle_task_result, fn state, ref, result ->
      send(test_pid, {:task_result, ref, result})
      state
    end)

    # Initialize the server manager with a connection action.
    initialize.([connect(host, port, username)])

    # Wait for the message indicating that the faker server connection has
    # received and forwarded the connection call.
    assert_receive {:proxy, ^server_conn,
                    {:call, {:connect, ^host, ^port, ^username, silently_accept_hosts: true},
                     from}},
                   1000

    # Ensure that the server manager has called the connection function.
    assert_receive {:connect_task, connect_task}, 1000
    refute_received _anything_else

    # Simulate a successful reply from the fake server connection.
    connection_ref = make_ref()
    GenServer.reply(from, {:ok, connection_ref})

    # Ensure that the server manager has received the connection task result.
    connect_task_ref = connect_task.ref
    assert_receive {:task_result, ^connect_task_ref, {:ok, ^connection_ref}}, 1000
    refute_received _anything_else
  end

  test "have a server manager monitor another process", %{
    initialize: initialize,
    test_pid: test_pid
  } do
    # Start another process that will be monitored by the server manager.
    pid = start_supervised!(NoOpGenServer)

    # Expect the server manager to receive a connection crashed message when the
    # monitored process crashes. Send a :done message to the test process when
    # that happens, marking the end of the test.
    expect(ServerManagerMock, :connection_crashed, fn state, ^pid, :oops ->
      send(test_pid, :done)
      state
    end)

    # Have the server manager forward the :started message to the test process.
    # We use this message to know when the server manager has finished
    # initializing, before we simulate the crash of the monitored process.
    expect(ServerManagerMock, :on_message, fn state, :started ->
      send(test_pid, :started)
      state
    end)

    # Initialize the server manager, have it monitor the other process, and wait
    # for it to finish initializing.
    initialize.([monitor(pid), send_message(:started)])
    assert_receive :started, 1000

    # Simulate a crash of the monitored process.
    Process.exit(pid, :oops)

    # Ensure that the server manager has received the crash message.
    assert_receive :done, 1000
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

    start_link_supervised!(%{
      id: ServerManager,
      start: {ServerManager, :start_link, [id, pipeline, opts]}
    })

    assert_receive :initialized, 500
    refute_received _anything_else
  end

  defp cancel_timer(ref), do: {:cancel_timer, ref}

  defp connect(host, port, username) do
    test_pid = self()

    {:connect,
     fn state, task_factory ->
       task = task_factory.(host, port, username, silently_accept_hosts: true)
       send(test_pid, {:connect_task, task})
       state
     end}
  end

  defp monitor(pid), do: {:monitor, pid}

  defp send_message(message, ms \\ 0),
    do:
      {:send_message,
       fn state, task_factory ->
         task_factory.(message, ms)
         state
       end}
end
