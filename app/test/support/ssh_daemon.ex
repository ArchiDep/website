defmodule ArchiDep.Support.SSHDaemon do
  @moduledoc """
  Starts an in-process Erlang `:ssh` daemon on an ephemeral loopback port for
  the SSH client compatibility smoke test (see the "Testing external-tool
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
    * `host_key_kind: kind` chooses the kind of the daemon's ephemeral host key
      (`:ed25519` by default, `:ecdsa_nistp256`, `:ecdsa_nistp384`,
      `:ecdsa_nistp521` or `:rsa`), which is returned as `host_key` so that a
      test can verify what the client is presented with. Its fingerprint and
      algorithm, as `ssh-keygen -l` describes them independently of this
      application, are returned as `host_key_description`.

  The daemon and its temporary key directories are torn down with `on_exit/1`.
  """

  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHHostKey

  @enforce_keys [:host, :port, :username, :host_key, :host_key_description]
  defstruct [:host, :port, :username, :host_key, :host_key_description]

  @type t :: %__MODULE__{
          host: :inet.ip_address(),
          port: :inet.port_number(),
          username: String.t(),
          host_key: SSHHostKey.t(),
          host_key_description: {fingerprint :: String.t(), algorithm :: String.t()}
        }

  @type host_key_kind :: :ed25519 | :ecdsa_nistp256 | :ecdsa_nistp384 | :ecdsa_nistp521 | :rsa

  @type option ::
          {:authorize_client, boolean()}
          | {:kex_algorithms, [atom()]}
          | {:host_key_kind, host_key_kind()}

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

    # An ephemeral host key for the daemon, in the file the daemon loads host
    # keys of that kind from.
    {key_file, keygen_args} = host_key_file(Keyword.get(opts, :host_key_kind, :ed25519))
    host_key_path = Path.join(system_dir, key_file)

    {_output, 0} =
      System.cmd("ssh-keygen", ["-q", "-N", "", "-f", host_key_path | keygen_args], env: %{})

    public_key_path = host_key_path <> ".pub"
    {:ok, host_key} = public_key_path |> File.read!() |> SSHHostKey.parse()
    {description, 0} = System.cmd("ssh-keygen", ["-l", "-f", public_key_path], env: %{})

    [_match, fingerprint, algorithm] =
      Regex.run(~r/\A\d+ (SHA256:\S+) .* \(([A-Z0-9]+)\)\z/, String.trim(description))

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

    %__MODULE__{
      host: @host,
      port: Keyword.fetch!(info, :port),
      username: @username,
      host_key: host_key,
      host_key_description: {fingerprint, algorithm}
    }
  end

  defp host_key_file(:ed25519), do: {"ssh_host_ed25519_key", ["-t", "ed25519"]}
  defp host_key_file(:ecdsa_nistp256), do: {"ssh_host_ecdsa_key", ["-t", "ecdsa", "-b", "256"]}
  defp host_key_file(:ecdsa_nistp384), do: {"ssh_host_ecdsa_key", ["-t", "ecdsa", "-b", "384"]}
  defp host_key_file(:ecdsa_nistp521), do: {"ssh_host_ecdsa_key", ["-t", "ecdsa", "-b", "521"]}
  defp host_key_file(:rsa), do: {"ssh_host_rsa_key", ["-t", "rsa", "-b", "2048"]}

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
