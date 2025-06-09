defmodule ArchiDep.Servers.ServerManager do
  use GenServer

  require Logger
  alias ArchiDep.Servers.Schemas.Server

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: {:global, {:server, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server manager for server #{server_id}")
    {:ok, server_id, {:continue, :connect_to_server}}
  end

  @impl true
  def handle_continue(:connect_to_server, server_id) do
    {:ok, server} = Server.fetch_server(server_id)

    Logger.info(
      "Opening SSH connection to server #{server_id} as #{server.username} at #{server.ip_address} on port 22"
    )

    connection_task =
      Task.async(fn ->
        :ssh.connect(
          server.ip_address.address,
          2222,
          auth_methods: ~c"publickey",
          connect_timeout: 30_000,
          save_accepted_host: false,
          silently_accept_hosts: true,
          user: to_charlist(server.username),
          user_dir: to_charlist("../tmp/jde"),
          user_interaction: false
        )
      end)

    # Logger.info("Opening a channel for server #{server_id}")
    # {:ok, channel_ref} = :ssh_connection.session_channel(connection_ref, 30_000)

    # :success = :ssh_connection.exec(connection_ref, channel_ref, ~c"pwd", 30_000)

    {:noreply, {:connecting, server_id, connection_task.ref}}
  end

  @impl true
  def handle_info({ref, result}, {:connecting, server_id, ref}) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, connection_ref} ->
        Process.link(connection_ref)
        Logger.info("Successfully opened an SSH connection to server #{server_id}")
        {:noreply, {:connected, server_id, connection_ref}}

      {:error, reason} ->
        Logger.info(
          "Could not open SSH connection to server #{server_id} because #{inspect(reason)}"
        )

        {:noreply, {:not_connected, server_id, reason}}
    end
  end

  @impl true
  def terminate(_reason, {:connected, _server_id, connection_ref}) do
    :ssh.close(connection_ref)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end
end
