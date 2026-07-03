defmodule ArchiDep.Servers.ServerTracking.ServerConnection do
  @moduledoc """
  SSH connection to a specific server, used for tracking state and running
  commands. This process is linked to the SSH connection process and will crash
  if the connection is lost. It will then be restarted by its supervisor and
  instructed to open a new connection by the sibling
  `ArchiDep.Servers.ServerTracking.ServerManager` process.
  """

  use GenServer

  import ArchiDep.Servers.Helpers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.Client
  alias ArchiDep.Servers.SSH.ConnectError
  alias Ecto.UUID
  require Logger

  @type connect_options :: [connect_option()]
  @type connect_option :: {:silently_accept_hosts, boolean()}

  @connection_timeout Application.compile_env!(
                        :archidep,
                        [:servers, :connection_timeout]
                      )

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: name(server_id)

  @spec name(UUID.t()) :: GenServer.name()
  def name(server_id), do: {:global, {__MODULE__, server_id}}

  @spec start_link(UUID.t()) :: GenServer.on_start()
  def start_link(server_id),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server_id))

  @spec connect(Server.t(), :inet.ip_address(), 1..65_535, String.t(), connect_options) ::
          :ok | {:error, term()}
  def connect(server, host, port, username, options \\ []),
    do: GenServer.call(name(server), {:connect, host, port, username, options}, 45_000)

  @spec run_command(Server.t(), String.t(), pos_integer()) ::
          {:ok, String.t(), String.t(), 0..255} | {:error, :not_connected} | {:error, term()}
  def run_command(server, command, timeout),
    do: GenServer.call(name(server), {:run_command, command, timeout}, timeout)

  @spec disconnect(Server.t()) :: :ok
  def disconnect(server), do: GenServer.call(name(server), :disconnect)

  # Server callbacks

  @impl GenServer
  def init(server_id) do
    Logger.debug("Init server connection for server #{server_id}")
    {:ok, server_id, {:continue, :idle}}
  end

  @impl GenServer
  def handle_continue(:idle, server_id) do
    set_process_label(__MODULE__, server_id)
    ServerManager.connection_idle(server_id, self())
    {:noreply, {:idle, server_id}}
  end

  @impl GenServer

  def handle_call({:connect, host, port, username, options}, _from, {:idle, server_id}) do
    open_ssh_connection(host, port, username, options, server_id)
  end

  def handle_call(
        {:connect, host, port, username, options},
        _from,
        {:connected, connection_ref, server_id}
      ) do
    Process.unlink(connection_ref)

    case Client.close(connection_ref) do
      :ok ->
        Logger.debug("Closed SSH connection to server #{server_id}")

      {:error, reason} ->
        Logger.warning(
          "Failed to close SSH connection to server #{server_id} because: #{inspect(reason)}"
        )
    end

    open_ssh_connection(host, port, username, options, server_id)
  end

  def handle_call(
        {:run_command, command, timeout},
        _from,
        {:connected, connection_ref, server_id}
      ) do
    result =
      Client.run_command(connection_ref, command,
        channel_timeout: div(timeout, 2),
        exec_timeout: div(timeout, 2),
        separate_streams: true
      )

    {:reply, result, {:connected, connection_ref, server_id}}
  end

  def handle_call({:run_command, _command, _timeout}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:disconnect, _from, {:connected, connection_ref, server_id}) do
    Process.unlink(connection_ref)

    case Client.close(connection_ref) do
      :ok ->
        Logger.debug("Closed SSH connection to server #{server_id}")

      {:error, reason} ->
        Logger.warning(
          "Failed to close SSH connection to server #{server_id} because: #{inspect(reason)}"
        )
    end

    {:reply, :ok, {:idle, server_id}}
  end

  @impl GenServer
  def terminate(_reason, {:connected, connection_ref, server_id}) do
    case Client.close(connection_ref) do
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
    target = "#{username}@#{:inet.ntoa(host)}:#{port}"
    Logger.debug("Opening SSH connection to server #{server_id} (#{target})")

    result =
      Client.connect(
        host,
        port,
        auth_methods: ~c"publickey",
        connect_timeout: @connection_timeout,
        # key_cb: {:ssh_agent, timeout: 5000},
        save_accepted_host: false,
        silently_accept_hosts: Keyword.get(options, :silently_accept_hosts, false),
        user: to_charlist(username),
        user_dir: to_charlist(SSH.ssh_dir()),
        user_interaction: false
      )

    case result do
      {:ok, connection_ref} ->
        Process.link(connection_ref)

        Logger.debug("Successfully opened an SSH connection to server #{server_id} (#{target})")

        {:reply, :ok, {:connected, connection_ref, server_id}}

      {:error, reason} ->
        handle_connect_error(reason, server_id, target)
    end
  end

  # Erlang's SSH library reports these failures as strings; `ConnectError` owns
  # the strings and maps them to stable atoms.
  defp handle_connect_error(reason, server_id, target) do
    case ConnectError.classify(reason) do
      :authentication_failed ->
        Logger.warning("Could not authenticate SSH connection to server #{server_id} (#{target})")

        {:reply, {:error, :authentication_failed}, {:idle, server_id}}

      :key_exchange_failed ->
        Logger.warning(
          "Could not open SSH connection to server #{server_id} (#{target}) because the key exchange failed"
        )

        {:reply, {:error, :key_exchange_failed}, {:idle, server_id}}

      :other ->
        Logger.debug(
          "Could not open SSH connection to server #{server_id} (#{target}) because #{inspect(reason)}"
        )

        {:reply, {:error, reason}, {:idle, server_id}}
    end
  end
end
