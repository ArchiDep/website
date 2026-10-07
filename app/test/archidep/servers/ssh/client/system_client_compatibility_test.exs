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
  #
  # Host keys are verified by `KeyCallback`, which plugs into `:ssh` as its
  # `key_cb`, so these tests also certify the `:ssh` side of that contract: the
  # key and algorithm it hands the callback for each kind of host key, that a
  # rejected key fails the connection as a key exchange failure, and that the
  # callback still loads the client key used to authenticate.
  use ExUnit.Case, async: true

  import Hammox
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.Client
  alias ArchiDep.Servers.SSH.Client.SystemClient
  alias ArchiDep.Servers.SSH.ConnectError
  alias ArchiDep.Servers.SSH.KeyCallback
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.SSHDaemon

  @host_key_kinds [:ed25519, :ecdsa_nistp256, :ecdsa_nistp384, :ecdsa_nistp521, :rsa]

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
    assert {:ok, connection_ref} = connect(daemon, verify_host_key(true))

    assert Client.run_command(connection_ref, "echo hello", separate_streams: true) ==
             {:ok, "hello\n", "", 0}

    assert Client.close(connection_ref) == :ok

    assert verified_host_keys() == [daemon.host_key_description]
  end

  test "the real SSH client returns the authentication-failure error tuple" do
    daemon = SSHDaemon.start!(authorize_client: false)

    assert connect(daemon, verify_host_key(true)) == ConnectError.authentication_failed()
    assert verified_host_keys() == [daemon.host_key_description]
  end

  test "the real SSH client returns the key-exchange-failure error tuple" do
    # The daemon and the client each offer a single, distinct key-exchange
    # algorithm, so negotiation finds no common one.
    [daemon_kex, client_kex | _rest] = Keyword.fetch!(:ssh.default_algorithms(), :kex)
    daemon = SSHDaemon.start!(kex_algorithms: [daemon_kex])

    assert connect(daemon, verify_host_key(true), preferred_algorithms: [kex: [client_kex]]) ==
             ConnectError.key_exchange_failed()

    # Negotiation fails before the server presents its host key.
    assert verified_host_keys() == []
  end

  for kind <- @host_key_kinds do
    test "the real SSH client verifies an accepted #{kind} host key with its fingerprint and algorithm" do
      daemon = SSHDaemon.start!(host_key_kind: unquote(kind))

      assert {:ok, connection_ref} = connect(daemon, verify_host_key(true))

      assert Client.run_command(connection_ref, "echo hi", separate_streams: true) ==
               {:ok, "hi\n", "", 0}

      assert Client.close(connection_ref) == :ok

      assert verified_host_keys() == [daemon.host_key_description]
    end

    test "the real SSH client fails like a key exchange failure when a #{kind} host key is rejected" do
      # A rejected host key must fail with the reason `ConnectError` classifies
      # as a key exchange failure: that is what makes the server manager show
      # the fingerprint and algorithm reported by the rejected verification.
      daemon = SSHDaemon.start!(host_key_kind: unquote(kind))

      assert connect(daemon, verify_host_key(false)) == ConnectError.key_exchange_failed()
      assert verified_host_keys() == [daemon.host_key_description]
    end
  end

  test "the real SSH client reports the same fingerprint and algorithm as the server's registered public key" do
    # Production compares the fingerprint the callback receives to the
    # fingerprints of the public keys registered for the server, which are
    # parsed from the text form of the keys. Pin that both sides agree on a key
    # read the way a student would register it.
    daemon = SSHDaemon.start!(host_key_kind: :ecdsa_nistp384)
    {:ok, registered_key} = daemon.host_key |> SSHHostKey.to_openssh() |> SSHHostKey.parse()

    assert {:ok, connection_ref} = connect(daemon, verify_host_key(true))
    assert Client.close(connection_ref) == :ok

    assert verified_host_keys() == [
             {SSHHostKey.fingerprint(registered_key, :sha256), "ECDSA"}
           ]
  end

  test "the real SSH client does not let silently_accept_hosts accept a host key the key callback rejects" do
    # The key callback fails the connection itself instead of deferring to
    # `silently_accept_hosts`, so even an option accepting every host cannot
    # override its decision.
    daemon = SSHDaemon.start!()

    assert connect(daemon, verify_host_key(false), silently_accept_hosts: true) ==
             ConnectError.key_exchange_failed()

    assert verified_host_keys() == [daemon.host_key_description]
  end

  # The same options `ServerConnection` connects with (see its tests, which pin
  # them exactly), apart from the timeout.
  defp connect(daemon, verify_host_key, extra_opts \\ []) do
    Client.connect(
      daemon.host,
      daemon.port,
      Keyword.merge(
        [
          auth_methods: ~c"publickey",
          connect_timeout: 5_000,
          key_cb: {KeyCallback, verify_host_key: verify_host_key},
          save_accepted_host: false,
          silently_accept_hosts: false,
          user: to_charlist(daemon.username),
          user_dir: to_charlist(SSH.ssh_dir()),
          user_interaction: false
        ],
        extra_opts
      )
    )
  end

  # A host key verification function that reports each key it is given to the
  # test process, and trusts it or not.
  defp verify_host_key(trusted) do
    test_pid = self()

    fn fingerprint, algorithm ->
      send(test_pid, {:verify_host_key, fingerprint, algorithm})
      trusted
    end
  end

  # The host keys the verification function was given, in order. The function
  # runs in the SSH connection process, and `:ssh.connect/3` only returns in the
  # test process once that same process has sent it the outcome of the handshake
  # (a message or a monitor's `:DOWN`). Signals between two processes arrive in
  # the order they were sent, so every message the function sent is already in
  # the mailbox and none can arrive later.
  defp verified_host_keys(acc \\ []) do
    receive do
      {:verify_host_key, fingerprint, algorithm} ->
        verified_host_keys([{fingerprint, algorithm} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
