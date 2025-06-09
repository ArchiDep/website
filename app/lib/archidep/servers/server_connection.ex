defmodule ArchiDep.Servers.ServerConnection do
  use GenServer

  require Logger
  alias ArchiDep.Servers.Schemas.Server

  @type connect_options :: [connect_option()]

  @type connect_option ::
          {:host, :inet.ip_address()}
          | {:port, 1..65_535}
          | {:silently_accept_hosts, boolean()}
          | {:user, String.t()}

  # Client API

  @spec name(Server.t()) :: GenServer.name()
  def name(%Server{id: server_id}), do: {:global, {:server_connection, server_id}}

  @spec start_link(Server.t()) :: GenServer.on_start()
  def start_link(%Server{id: server_id} = server),
    do: GenServer.start_link(__MODULE__, server_id, name: name(server))

  @spec connect(Server.t(), connect_options()) :: :ok | {:error, term()}
  def connect(server, options \\ []) do
    GenServer.call(name(server), {:connect, options}, 30_000)
  end

  # Server callbacks

  @impl true
  def init(server_id) do
    Logger.debug("Init server connection for server #{server_id}")
    {:ok, {:idle, server_id}}
  end

  @impl true
  def handle_call({:connect, options}, from, {:idle, server_id}) do
    connecting_task =
      Task.async(fn ->
        :ssh.connect(
          Keyword.fetch!(options, :host),
          Keyword.fetch!(options, :port),
          auth_methods: ~c"publickey",
          connect_timeout: 30_000,
          save_accepted_host: false,
          silently_accept_hosts: Keyword.get(options, :silently_accept_hosts, false),
          user: options |> Keyword.fetch!(:username) |> to_charlist(),
          user_dir: to_charlist("../tmp/jde"),
          user_interaction: false
        )
      end)

    {:noreply, {:connecting, server_id, from, connecting_task.ref}}
  end

  @impl true
  def handle_info({ref, result}, {:connecting, server_id, from, ref}) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, connection_ref} ->
        Process.link(connection_ref)
        Logger.info("Successfully opened an SSH connection to server #{server_id}")
        GenServer.reply(from, {:ok, :connected})
        {:noreply, {:connected, server_id, connection_ref}}

      {:error, reason} ->
        Logger.info(
          "Could not open SSH connection to server #{server_id} because #{inspect(reason)}"
        )

        GenServer.reply(from, {:error, reason})

        {:noreply, {:not_connected, server_id, reason}}
    end
  end
end
