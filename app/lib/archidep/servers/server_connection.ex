defmodule ArchiDep.Servers.ServerConnection do
  use GenServer

  require Logger
  import ArchiDep.Servers.Helpers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager
  alias Ecto.UUID

  @type connect_options :: [connect_option()]
  @type connect_option :: {:silently_accept_hosts, boolean()}

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id), do: {:global, {:server_connection, server_id}}

  @spec start_link(UUID.t()) :: GenServer.on_start()
  def start_link(server_id),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server_id))

  @spec connect(Server.t(), :inet.ip_address(), 1..65_535, String.t(), connect_options) ::
          :ok | {:error, term()}
  def connect(server, host, port, username, options \\ []),
    do: GenServer.call(name(server), {:connect, host, port, username, options}, 30_000)

  @spec run_command(Server.t(), String.t(), pos_integer()) ::
          {:ok, String.t(), String.t(), 0..255} | {:error, term()}
  def run_command(server, command, timeout),
    do: GenServer.call(name(server), {:run_command, command}, timeout)

  @spec disconnect(Server.t()) :: :ok
  def disconnect(server), do: GenServer.call(name(server), :disconnect)

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server connection for server #{server_id}")
    set_process_label(__MODULE__, server_id)
    {:ok, server_id, {:continue, :idle}}
  end

  @impl true
  def handle_continue(:idle, server_id) do
    ServerManager.connection_idle(server_id, self())
    {:noreply, {:idle, server_id}}
  end

  @impl true

  def handle_call({:connect, host, port, username, options}, _from, {:idle, server_id}) do
    open_ssh_connection(host, port, username, options, server_id)
  end

  def handle_call(
        {:connect, host, port, username, options},
        _from,
        {:connected, connection_ref, server_id}
      ) do
    Process.unlink(connection_ref)

    case :ssh.close(connection_ref) do
      :ok ->
        Logger.debug("Closed SSH connection to server #{server_id}")

      {:error, reason} ->
        Logger.warning(
          "Failed to close SSH connection to server #{server_id} because: #{inspect(reason)}"
        )
    end

    open_ssh_connection(host, port, username, options, server_id)
  end

  def handle_call({:run_command, command}, _from, {:connected, connection_ref, server_id}) do
    result = SSHEx.run(connection_ref, command, separate_streams: true)
    {:reply, result, {:connected, connection_ref, server_id}}
  end

  def handle_call({:run_command, _command}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:disconnect, _from, {:connected, connection_ref, server_id}) do
    Process.unlink(connection_ref)

    case :ssh.close(connection_ref) do
      :ok ->
        Logger.debug("Closed SSH connection to server #{server_id}")
    end

    {:reply, :ok, {:idle, server_id}}
  end

  @impl true
  def terminate(_reason, {:connected, connection_ref, server_id}) do
    case :ssh.close(connection_ref) do
      :ok ->
        Logger.debug("Closed SSH connection to server #{server_id}")

      {:error, reason} ->
        Logger.warning(
          "Failed to close SSH connection to server #{server_id} because: #{inspect(reason)}"
        )
    end

    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp open_ssh_connection(host, port, username, options, server_id) do
    Logger.debug(
      "Opening SSH connection to server #{server_id} (#{username}@#{:inet.ntoa(host)}:#{port})"
    )

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

        Logger.debug(
          "Successfully opened an SSH connection to server #{server_id} (#{username}@#{:inet.ntoa(host)}:#{port})"
        )

        {:reply, :ok, {:connected, connection_ref, server_id}}

      # Yes, Erlang's SSH library actually returns a string for this error.
      {:error, ~c"Unable to connect using the available authentication methods"} ->
        Logger.warning(
          "Could not authenticate SSH connection to server #{server_id} (#{username}@#{:inet.ntoa(host)}:#{port})"
        )

        {:reply, {:error, :authentication_failed}, {:idle, server_id}}

      {:error, reason} ->
        Logger.debug(
          "Could not open SSH connection to server #{server_id} (#{username}@#{:inet.ntoa(host)}:#{port}) because #{inspect(reason)}"
        )

        {:reply, {:error, reason}, {:idle, server_id}}
    end
  end
end
