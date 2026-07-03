defmodule ArchiDep.Support.SSHDaemon do
  @moduledoc """
  Starts an in-process Erlang `:ssh` daemon on an ephemeral loopback port for
  the external-tool compatibility smoke tests (see the "Testing external-tool
  compatibility" section in `docs/testing.md`).

  By default the daemon authorizes the `test/priv/ssh` client fixture for
  publickey authentication, so a test can drive the real
  `ArchiDep.Servers.SSH.Client` implementation against it with the same
  connection options production uses. Options make it reproduce failure modes
  too:

    * `authorize_client: false` leaves the daemon's `authorized_keys` empty, so
      the fixture key is rejected and publickey authentication fails.
    * `kex_algorithms: [atom]` restricts the daemon's key-exchange algorithms,
      so a client offering a disjoint set triggers a key-exchange failure.

  The daemon and its temporary key directories are torn down with `on_exit/1`.
  """

  alias ArchiDep.Servers.SSH

  @enforce_keys [:host, :port, :username]
  defstruct [:host, :port, :username]

  @type t :: %__MODULE__{
          host: :inet.ip_address(),
          port: :inet.port_number(),
          username: String.t()
        }

  @type option :: {:authorize_client, boolean()} | {:kex_algorithms, [atom()]}

  @host {127, 0, 0, 1}
  @username "archidep"

  @doc """
  Starts the daemon and returns its address. Registers an `on_exit/1` callback
  that stops the daemon and removes its temporary directories, so the caller
  must run inside an ExUnit test process.
  """
  @spec start!([option()]) :: t()
  def start!(opts \\ []) do
    {:ok, _apps} = Application.ensure_all_started(:ssh)

    dir =
      Path.join(System.tmp_dir!(), "archidep-ssh-daemon-#{System.unique_integer([:positive])}")

    system_dir = Path.join(dir, "system")
    user_dir = Path.join(dir, "user")
    File.mkdir_p!(system_dir)
    File.mkdir_p!(user_dir)

    # An ephemeral host key for the daemon (the client silently accepts it).
    {_output, 0} =
      System.cmd(
        "ssh-keygen",
        ["-q", "-t", "ed25519", "-N", "", "-f", Path.join(system_dir, "ssh_host_ed25519_key")],
        env: %{}
      )

    # Authorize the client fixture's public key so publickey auth succeeds,
    # unless the test wants to reproduce an authentication failure.
    authorized_keys =
      if Keyword.get(opts, :authorize_client, true),
        do: File.read!(Path.join(SSH.ssh_dir(), "id_ed25519.pub")),
        else: ""

    File.write!(Path.join(user_dir, "authorized_keys"), authorized_keys)

    daemon_opts =
      [
        system_dir: to_charlist(system_dir),
        user_dir: to_charlist(user_dir),
        auth_methods: ~c"publickey",
        exec: {:direct, &run_exec_command/1}
      ] ++ kex_opts(opts)

    {:ok, daemon_ref} = :ssh.daemon(@host, 0, daemon_opts)

    {:ok, info} = :ssh.daemon_info(daemon_ref)

    ExUnit.Callbacks.on_exit(fn ->
      :ssh.stop_daemon(daemon_ref)
      File.rm_rf!(dir)
    end)

    %__MODULE__{host: @host, port: Keyword.fetch!(info, :port), username: @username}
  end

  defp kex_opts(opts) do
    case Keyword.get(opts, :kex_algorithms) do
      nil -> []
      kex -> [preferred_algorithms: [kex: kex]]
    end
  end

  # The Erlang daemon runs an Erlang shell by default; run exec'd commands
  # through the OS shell so a smoke test gets a real command round-trip.
  defp run_exec_command(command) do
    {output, _status} = System.cmd("sh", ["-c", to_string(command)], env: %{})
    {:ok, output}
  end
end
