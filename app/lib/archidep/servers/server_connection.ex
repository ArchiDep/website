defmodule ArchiDep.Servers.ServerConnection do
  use GenServer

  require Logger
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager

  @type connect_options :: [connect_option()]
  @type connect_option :: {:silently_accept_hosts, boolean()}

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: {:global, {:server_connection, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  @spec connect(Server.t(), :inet.ip_address(), 1..65_535, String.t(), connect_options) ::
          :ok | {:error, term()}
  def connect(server, host, port, username, options \\ []),
    do: GenServer.call(name(server), {:connect, host, port, username, options}, 30_000)

  @spec run_command(Server.t(), String.t(), pos_integer()) ::
          {:ok, String.t(), String.t(), 0..255} | {:error, term()}
  def run_command(server, command, timeout),
    do: GenServer.call(name(server), {:run_command, command}, timeout)

  @spec ping_load_average(Server.t(), reference()) :: :ok
  def ping_load_average(server, ref),
    do: GenServer.cast(name(server), {:ping_load_average, self(), ref})

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server connection for server #{server_id}")
    {:ok, server_id, {:continue, :idle}}
  end

  @impl true
  def handle_continue(:idle, server_id) do
    ServerManager.connection_idle(server_id, self())
    {:noreply, {:idle, server_id}}
  end

  @impl true
  def handle_call({:connect, host, port, username, options}, _from, {:idle, server_id}) do
    Logger.debug("Opening SSH connection to server #{server_id}")

    result =
      :ssh.connect(
        host,
        port,
        auth_methods: ~c"publickey",
        connect_timeout: 30_000,
        # key_cb: {:ssh_agent, timeout: 5000},
        save_accepted_host: false,
        silently_accept_hosts: Keyword.get(options, :silently_accept_hosts, false),
        user: to_charlist(username),
        user_dir: to_charlist("../tmp/jde"),
        user_interaction: false
      )

    case result do
      {:ok, connection_ref} ->
        Process.link(connection_ref)
        Logger.info("Successfully opened an SSH connection to server #{server_id}")
        {:reply, :ok, {:connected, connection_ref, server_id}}

      {:error, reason} ->
        Logger.info(
          "Could not open SSH connection to server #{server_id} because #{inspect(reason)}"
        )

        {:reply, {:error, reason}, {:idle, server_id}}
    end
  end

  def handle_call({:run_command, command}, _from, {:connected, connection_ref, server_id}) do
    result = SSHEx.run(connection_ref, command, separate_streams: true)
    {:reply, result, {:connected, connection_ref, server_id}}
  end

  def handle_call({:run_command, _command}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  @impl true
  def handle_cast({:ping_load_average, from, ref}, {:connected, connection_ref, server_id}) do
    before_call = DateTime.utc_now()

    with {:ok, stdout, _stderr, 0} <-
           SSHEx.run(connection_ref, "cat /proc/loadavg", separate_streams: true),
         after_call = DateTime.utc_now(),
         [m1s, m5s, m15s | _rest] <- stdout |> String.trim() |> String.split(~r/\s+/),
         [{m1, ""}, {m5, ""}, {m15, ""}] <- [
           Float.parse(m1s),
           Float.parse(m5s),
           Float.parse(m15s)
         ] do
      send(from, {:load_average, ref, {m1, m5, m15, before_call, after_call}})
    end

    {:noreply, {:connected, connection_ref, server_id}}
  end

  def handle_cast({:ping_load_average, _from}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, {:connected, connection_ref, _server_id}) do
    case :ssh.close(connection_ref) do
      :ok ->
        Logger.debug("SSH connection closed successfully")

      {:error, reason} ->
        Logger.warning("Failed to close SSH connection: #{inspect(reason)}")
    end

    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end
end
