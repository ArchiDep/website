defmodule ArchiDep.Servers.SSH.Client.SystemClientCompatibilityTest do
  # Certifies that the real `:ssh`/`SSHEx` stack the production
  # `ArchiDep.Servers.SSH.Client.SystemClient` wraps still speaks the protocol
  # the app drives — a canary for OTP/SSHEx drift that every mocked unit test
  # misses. The two error cases pin the exact `:ssh` failure tuples that
  # `ConnectError` owns and classifies. See the "Testing external-tool
  # compatibility" section in `docs/testing.md`.
  #
  # The system under test — the Erlang `:ssh`/`SSHEx` stack driven against an
  # in-process `:ssh.daemon` — is within the Elixir/Erlang ecosystem, so this
  # runs in the standard suite (unlike the Ansible smoke tests, which drive a
  # foreign tool and stay `:external`), and it gives `SystemClient` real
  # coverage.
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.Client
  alias ArchiDep.Servers.SSH.Client.SystemClient
  alias ArchiDep.Servers.SSH.ConnectError
  alias ArchiDep.Support.SSHDaemon

  setup :verify_on_exit!

  setup do
    # Point the compile-time façade mock at the real implementation, so calls
    # through `Client` hit `:ssh`/`SSHEx` for real against an in-process daemon.
    stub_with(Client.Mock, SystemClient)
    :ok
  end

  test "the real SSH client connects, runs a command and disconnects" do
    daemon = SSHDaemon.start!()

    # The opaque connection reference is a runtime handle with no predictable
    # value; the `:ok` tag is the whole assertable content of the tuple.
    assert {:ok, connection_ref} = connect(daemon)

    assert Client.run_command(connection_ref, "echo hello", separate_streams: true) ==
             {:ok, "hello\n", "", 0}

    assert Client.close(connection_ref) == :ok
  end

  test "the real SSH client returns the authentication-failure error tuple" do
    daemon = SSHDaemon.start!(authorize_client: false)

    assert connect(daemon) == ConnectError.authentication_failed()
  end

  test "the real SSH client returns the key-exchange-failure error tuple" do
    # The daemon and the client each offer a single, distinct key-exchange
    # algorithm, so negotiation finds no common one.
    [daemon_kex, client_kex | _rest] = Keyword.fetch!(:ssh.default_algorithms(), :kex)
    daemon = SSHDaemon.start!(kex_algorithms: [daemon_kex])

    assert connect(daemon, preferred_algorithms: [kex: [client_kex]]) ==
             ConnectError.key_exchange_failed()
  end

  test "the real SSH client rejects an unverified host key unless hosts are silently accepted" do
    # The daemon's host key is ephemeral and absent from the client's
    # `user_dir`, so it is unknown. Production defaults to
    # `silently_accept_hosts: false` (host keys are verified), and real `:ssh`
    # must reject the unknown host — the security property `ServerConnection`
    # relies on. The rejection reason is not one of the strings `ConnectError`
    # classifies, so it maps to `:other` (the raw reason passes through,
    # carrying no app-level format contract); pin that classification rather
    # than the exact string.
    daemon = SSHDaemon.start!()

    assert {:error, reason} = connect(daemon, silently_accept_hosts: false)
    assert ConnectError.classify(reason) == :other
  end

  defp connect(daemon, extra_opts \\ []) do
    Client.connect(
      daemon.host,
      daemon.port,
      Keyword.merge(
        [
          auth_methods: ~c"publickey",
          connect_timeout: 5_000,
          save_accepted_host: false,
          silently_accept_hosts: true,
          user: to_charlist(daemon.username),
          user_dir: to_charlist(SSH.ssh_dir()),
          user_interaction: false
        ],
        extra_opts
      )
    )
  end
end
