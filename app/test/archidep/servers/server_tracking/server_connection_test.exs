defmodule ArchiDep.Servers.ServerTracking.ServerConnectionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.Client
  alias ArchiDep.Servers.SSH.ConnectError
  alias ArchiDep.Support.GenServerProxy
  alias ArchiDep.Support.NoOpGenServer
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup do
    # A fresh server ID gives this test unique global names for both the
    # connection (the unit under test) and its sibling manager, so the test is
    # fully isolated and can run async.
    server = ServersFactory.build(:server)
    server_id = server.id
    manager_name = ServerManager.name(server_id)

    # Stand in for the sibling `ServerManager` so the boot-time
    # `connection_idle` cast lands on a process the test can observe.
    start_supervised!(%{
      id: :server_manager_proxy,
      start: {GenServerProxy, :start_link, [self(), manager_name]}
    })

    # A closing connection at process teardown must not fail; specific tests
    # override this with an `expect` to assert the close.
    stub(Client.Mock, :close, fn _connection_ref -> :ok end)

    %{server: server, server_id: server_id, manager_name: manager_name}
  end

  test "a connection notifies its manager that it is idle when it boots", %{
    server_id: server_id,
    manager_name: manager_name
  } do
    conn = start_connection!(server_id)

    assert_receive {:proxy, ^manager_name, {:cast, {:connection_idle, ^conn}}}, 500
  end

  test "open an SSH connection to a server", %{server: server, server_id: server_id} do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)

    expect(Client.Mock, :connect, fn host, port, opts ->
      send(test_pid, {:connect_called, host, port, opts})
      {:ok, connection_ref}
    end)

    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root", silently_accept_hosts: true) ==
             :ok

    assert_receive {:connect_called, {1, 2, 3, 4}, 22, opts}, 500
    assert opts == expected_connect_opts(true)
  end

  test "opening an SSH connection defaults to not silently accepting hosts", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)

    expect(Client.Mock, :connect, fn _host, _port, opts ->
      send(test_pid, {:connect_called, opts})
      {:ok, connection_ref}
    end)

    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    assert_receive {:connect_called, opts}, 500
    assert opts == expected_connect_opts(false)
  end

  test "opening an SSH connection maps an authentication failure", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    expect(Client.Mock, :connect, fn _host, _port, _opts ->
      ConnectError.authentication_failed()
    end)

    {result, log} = with_log(fn -> ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") end)

    assert result == {:error, :authentication_failed}

    assert log =~
             "Could not authenticate SSH connection to server #{server_id} (root@1.2.3.4:22)"
  end

  test "opening an SSH connection maps a key exchange failure", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    expect(Client.Mock, :connect, fn _host, _port, _opts ->
      ConnectError.key_exchange_failed()
    end)

    {result, log} = with_log(fn -> ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") end)

    assert result == {:error, :key_exchange_failed}

    assert log =~
             "Could not open SSH connection to server #{server_id} (root@1.2.3.4:22) because the key exchange failed"
  end

  test "opening an SSH connection passes through any other error", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:error, :econnrefused} end)

    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == {:error, :econnrefused}
  end

  test "reopening an SSH connection closes the previous one", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    first_ref = start_connection_ref!(:first_connection_ref)
    second_ref = start_connection_ref!(:second_connection_ref)

    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, first_ref} end)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, second_ref} end)

    expect(Client.Mock, :close, fn ^first_ref ->
      send(test_pid, {:closed, first_ref})
      :ok
    end)

    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    assert_receive {:closed, ^first_ref}, 500
  end

  test "run a command over a connected connection", %{server: server, server_id: server_id} do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, connection_ref} end)
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    expect(Client.Mock, :run_command, fn ^connection_ref, "uptime", opts ->
      send(test_pid, {:run_command_called, opts})
      {:ok, "up 1 day", "", 0}
    end)

    assert ServerConnection.run_command(server, "uptime", 4000) == {:ok, "up 1 day", "", 0}

    assert_receive {:run_command_called, opts}, 500
    assert opts == [channel_timeout: 2000, exec_timeout: 2000, separate_streams: true]
  end

  test "running a command over an idle connection reports it is not connected", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    assert ServerConnection.run_command(server, "uptime", 1000) == {:error, :not_connected}
  end

  test "disconnect a connected connection", %{server: server, server_id: server_id} do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, connection_ref} end)
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    expect(Client.Mock, :close, fn ^connection_ref ->
      send(test_pid, {:closed, connection_ref})
      :ok
    end)

    assert ServerConnection.disconnect(server) == :ok
    assert_receive {:closed, ^connection_ref}, 500

    # Disconnecting returns the process to the idle state.
    assert ServerConnection.run_command(server, "uptime", 1000) == {:error, :not_connected}
  end

  test "disconnecting logs but does not crash when closing the connection fails", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, connection_ref} end)
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    expect(Client.Mock, :close, fn ^connection_ref -> {:error, :closed} end)

    {result, log} = with_log(fn -> ServerConnection.disconnect(server) end)

    assert result == :ok
    assert log =~ "Failed to close SSH connection to server #{server_id} because: :closed"

    assert ServerConnection.run_command(server, "uptime", 1000) == {:error, :not_connected}
  end

  test "the SSH connection is closed when the process terminates", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    connection_ref = start_connection_ref!(:connection_ref)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, connection_ref} end)
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    expect(Client.Mock, :close, fn ^connection_ref ->
      send(test_pid, {:closed, connection_ref})
      :ok
    end)

    GenServer.stop(conn)
    assert_receive {:closed, ^connection_ref}, 500
  end

  test "a connection crashes when its SSH connection is lost", %{
    server: server,
    server_id: server_id
  } do
    test_pid = self()
    conn = start_and_idle!(server_id)
    allow(Client.Mock, test_pid, conn)

    # The connection process links to its SSH connection so that it crashes when
    # the connection is lost; killing the (fake) SSH connection exercises that.
    connection_ref = start_connection_ref!(:connection_ref)
    expect(Client.Mock, :connect, fn _host, _port, _opts -> {:ok, connection_ref} end)
    assert ServerConnection.connect(server, {1, 2, 3, 4}, 22, "root") == :ok

    monitor_ref = Process.monitor(conn)
    Process.exit(connection_ref, :kill)

    assert_receive {:DOWN, ^monitor_ref, :process, ^conn, :killed}, 500
  end

  defp start_connection!(server_id),
    do:
      start_supervised!(%{
        id: ServerConnection,
        start: {ServerConnection, :start_link, [server_id]},
        restart: :temporary
      })

  defp start_and_idle!(server_id) do
    conn = start_connection!(server_id)
    assert_receive {:proxy, _manager_name, {:cast, {:connection_idle, ^conn}}}, 500
    conn
  end

  defp start_connection_ref!(id),
    do:
      start_supervised!(%{
        id: id,
        start: {NoOpGenServer, :start_link, [nil]},
        restart: :temporary
      })

  defp connection_timeout,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:connection_timeout)

  # The full set of options the connection passes to the SSH boundary, so each
  # test asserts the whole options list by equality while varying only what it
  # exercises.
  defp expected_connect_opts(silently_accept_hosts),
    do: [
      auth_methods: ~c"publickey",
      connect_timeout: connection_timeout(),
      save_accepted_host: false,
      silently_accept_hosts: silently_accept_hosts,
      user: ~c"root",
      user_dir: to_charlist(SSH.ssh_dir()),
      user_interaction: false
    ]
end
