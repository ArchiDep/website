defmodule ArchiDep.Servers.SSH.KeyCallbackTest do
  # How real `:ssh` calls this module is certified by
  # `ArchiDep.Servers.SSH.Client.SystemClientCompatibilityTest`; these tests
  # cover each branch of the callbacks directly.
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH.KeyCallback
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.SSHFactory

  @ed448_oid {1, 3, 101, 113}

  describe "is_host_key/5" do
    for {kind, algorithm, algorithm_name} <- [
          {:ed25519, :"ssh-ed25519", "ED25519"},
          {:ecdsa_nistp256, :"ecdsa-sha2-nistp256", "ECDSA"},
          {:ecdsa_nistp384, :"ecdsa-sha2-nistp384", "ECDSA"},
          {:ecdsa_nistp521, :"ecdsa-sha2-nistp521", "ECDSA"},
          {:rsa, :"ssh-rsa", "RSA"}
        ] do
      test "trusts a #{kind} host key the verification function accepts, given its fingerprint and algorithm" do
        key = SSHFactory.random_ssh_host_key(unquote(kind))

        assert KeyCallback.is_host_key(
                 key.key,
                 [~c"server.example.com", {192, 0, 2, 10}],
                 2222,
                 unquote(algorithm),
                 opts(verify_host_key(true))
               ) == true

        assert verified_host_keys() == [
                 {SSHHostKey.fingerprint(key, :sha256), unquote(algorithm_name)}
               ]
      end

      test "fails on a #{kind} host key the verification function rejects, given its fingerprint and algorithm" do
        key = SSHFactory.random_ssh_host_key(unquote(kind))

        assert KeyCallback.is_host_key(
                 key.key,
                 [~c"server.example.com", {192, 0, 2, 10}],
                 22,
                 unquote(algorithm),
                 opts(verify_host_key(false))
               ) == {:error, :untrusted_host_key}

        assert verified_host_keys() == [
                 {SSHHostKey.fingerprint(key, :sha256), unquote(algorithm_name)}
               ]
      end
    end

    test "names the algorithm of a host key that cannot be registered by its type" do
      # `:ssh` supports Ed448 host keys, but `ssh-keygen` does not generate
      # them, so they are not among the keys a server can be registered with.
      {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed448)
      key = {{:ECPoint, public_key}, {:namedCurve, @ed448_oid}}

      assert KeyCallback.is_host_key(
               key,
               [~c"server.example.com", {192, 0, 2, 10}],
               22,
               :"ssh-ed448",
               opts(verify_host_key(false))
             ) == {:error, :untrusted_host_key}

      assert verified_host_keys() == [
               {:sha256 |> :ssh.hostkey_fingerprint(key) |> to_string(), "ssh-ed448"}
             ]
    end
  end

  describe "add_host_key/4" do
    test "never saves a host key" do
      key = SSHFactory.random_ssh_host_key()

      assert KeyCallback.add_host_key(
               [~c"server.example.com", {192, 0, 2, 10}],
               22,
               key.key,
               opts(verify_host_key(true))
             ) == {:error, :host_keys_are_not_saved}

      assert verified_host_keys() == []
    end
  end

  # The options `:ssh` passes to a key callback: the options given with the
  # `key_cb` option as `key_cb_private`, followed by some connection options.
  defp opts(verify_host_key),
    do: [key_cb_private: [verify_host_key: verify_host_key], user_dir: ~c"/nonexistent"]

  defp verify_host_key(trusted) do
    test_pid = self()

    fn fingerprint, algorithm ->
      send(test_pid, {:verify_host_key, fingerprint, algorithm})
      trusted
    end
  end

  # The callback calls the verification function in the calling process, so
  # every message it sent is already in the mailbox.
  defp verified_host_keys(acc \\ []) do
    receive do
      {:verify_host_key, fingerprint, algorithm} ->
        verified_host_keys([{fingerprint, algorithm} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
