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

    ref = make_ref()
    {:noreply, {:connecting, connection_task.ref, ref, server}}
  end

  @impl true
  def handle_info({connection_ref, result}, {:connecting, connection_ref, ref, server}) do
    Process.demonitor(connection_ref, [:flush])

    case result do
      :ok ->
        Logger.info("Server manager is connected to server #{server.id}")
        ServerConnection.ping_load_average(server, ref)
        {:noreply, {:connected, ref, server}}

      {:error, reason} ->
        Logger.info(
          "Server manager could not connect to server #{server.id} because #{inspect(reason)}"
        )

        {:noreply, {:not_connected, reason, server}}
    end
  end

  def handle_info(
        {:load_average, ref, {m1, m5, m15, before_call, after_call}},
        {:connected, ref, server}
      ) do
    Logger.info(
      "Received load average from server #{server.id}: #{m1}, #{m5}, #{m15} (between #{before_call} and #{after_call})"
    )

    {:noreply, {:connected, ref, server}}
  end
end
