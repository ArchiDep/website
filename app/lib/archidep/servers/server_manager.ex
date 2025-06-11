defmodule ArchiDep.Servers.ServerManager do
  use GenServer

  require Logger
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerConnection
  alias Ecto.UUID

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id) when is_binary(server_id), do: {:global, {:server_manager, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  @spec connection_idle(UUID.t(), pid()) :: :ok
  def connection_idle(server_id, connection_pid),
    do: GenServer.cast(name(server_id), {:connection_idle, connection_pid})

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server manager for server #{server_id}")
    {:ok, server_id, {:continue, :load_server}}
  end

  @impl true
  def handle_continue(:load_server, server_id) do
    {:ok, server} = Server.fetch_server(server_id)

    {:ok, _ref} =
      Phoenix.Tracker.track(ArchiDep.Tracker, self(), "servers", server.id, %{
        state: :idle
      })

    {:noreply, {:idle, server}}
  end

  @impl true
  def handle_cast({:connection_idle, connection_pid}, {:idle, server}) do
    Process.monitor(connection_pid)

    host = server.ip_address.address
    port = server.ssh_port || 22
    username = server.username

    connection_task =
      Task.async(fn ->
        ServerConnection.connect(
          server,
          host,
          port,
          username,
          silently_accept_hosts: true
        )
      end)

    connection_ref = make_ref()
    {:noreply, {:connecting, connection_task.ref, {connection_ref, connection_pid}, server}}
  end

  @impl true
  def handle_cast({:connection_idle, connection_pid}, {:connection_crashed, _reason, server}) do
    Process.monitor(connection_pid)

    host = server.ip_address.address
    port = server.ssh_port || 22
    username = server.username

    connection_task =
      Task.async(fn ->
        ServerConnection.connect(
          server,
          host,
          port,
          username,
          silently_accept_hosts: true
        )
      end)

    connection_ref = make_ref()
    {:noreply, {:connecting, connection_task.ref, {connection_ref, connection_pid}, server}}
  end

  @impl true
  def handle_info(
        {connection_task_ref, result},
        {:connecting, connection_task_ref, {connection_ref, connection_pid}, server}
      ) do
    Process.demonitor(connection_task_ref, [:flush])

    case result do
      :ok ->
        Logger.info("Server manager is connected to server #{server.id}")
        ServerConnection.ping_load_average(server, connection_ref)

        cmd =
          ~w(echo Hello)
          |> ExCmd.stream(exit_timeout: 30_000)
          |> Enum.into([])

        IO.puts(inspect(cmd))

        {:noreply, {:connected, {connection_ref, connection_pid}, server}}

      {:error, reason} ->
        Logger.info(
          "Server manager could not connect to server #{server.id} because #{inspect(reason)}"
        )

        {:noreply, {:not_connected, reason, server}}
    end
  end

  def handle_info(
        {:load_average, connection_ref, {m1, m5, m15, before_call, after_call}},
        {:connected, {connection_ref, connection_pid}, server}
      ) do
    Logger.info(
      "Received load average from server #{server.id}: #{m1}, #{m5}, #{m15} (between #{before_call} and #{after_call})"
    )

    {:noreply, {:connected, {connection_ref, connection_pid}, server}}
  end

  def handle_info(
        {:DOWN, _ref, :process, connection_pid, reason},
        {:connected, {_connection_ref, connection_pid}, server}
      ) do
    Logger.warning("Connection to server #{server.id} crashed: #{inspect(reason)}")

    {:noreply, {:connection_crashed, reason, server}}
  end
end
