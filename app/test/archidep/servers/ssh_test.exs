defmodule ArchiDep.Servers.SSHTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.SSHFactory
  alias Ecto.Changeset

  describe "parse_ssh_host_keys/1" do
    test "parses the output of 'cat /etc/ssh/ssh_host_*_key.pub'" do
      ecdsa_key = SSHFactory.random_ssh_host_key(:ecdsa)
      ed25519_key = SSHFactory.random_ssh_host_key(:ed25519)

      output = """
      #{SSHHostKey.to_openssh(ecdsa_key)} root@server
      #{SSHHostKey.to_openssh(ed25519_key)} root@server
      """

      assert SSH.parse_ssh_host_keys(output) == {:ok, [ecdsa_key, ed25519_key]}
    end

    test "parses the output of 'ssh-keyscan', ignoring its comment lines" do
      ed25519_key = SSHFactory.random_ssh_host_key(:ed25519)
      ecdsa_key = SSHFactory.random_ssh_host_key(:ecdsa)

      output = """
      # server.example.com:22 SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5
      server.example.com #{SSHHostKey.to_openssh(ed25519_key)}
      # server.example.com:22 SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5
      server.example.com #{SSHHostKey.to_openssh(ecdsa_key)}
      """

      assert SSH.parse_ssh_host_keys(output) == {:ok, [ed25519_key, ecdsa_key]}
    end

    test "ignores blank lines, surrounding whitespace and carriage returns" do
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      input =
        "\r\n  #{SSHHostKey.to_openssh(first_key)}  \r\n\n \t \n#{SSHHostKey.to_openssh(second_key)}\r\n\n"

      assert SSH.parse_ssh_host_keys(input) == {:ok, [first_key, second_key]}
    end

    test "keeps a key provided more than once only once" do
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      input = """
      #{SSHHostKey.to_openssh(first_key)} root@server
      #{SSHHostKey.to_openssh(second_key)}
      server.example.com #{SSHHostKey.to_openssh(first_key)}
      """

      assert SSH.parse_ssh_host_keys(input) == {:ok, [first_key, second_key]}
    end

    test "cannot parse text containing no keys" do
      assert Enum.map(
               ["", "   ", "\n", "\n \n\t", "# server.example.com:22 SSH-2.0-OpenSSH_9.6p1"],
               &SSH.parse_ssh_host_keys/1
             ) == List.duplicate({:error, :no_keys_found}, 5)
    end

    test "cannot parse text containing an invalid line, identifying each invalid line by number" do
      valid_key = SSHFactory.random_ssh_host_key()

      input = """
      #{SSHHostKey.to_openssh(valid_key)}

      256 SHA256:V0jnGyjc86bi1R3vTmyML4bwnqc/WVEK+Y0M09I3rWY root@server (ED25519)
      ssh-dss AAAAB3NzaC1kc3MAAACBAP root@server
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5!!!!
      """

      assert SSH.parse_ssh_host_keys(input) ==
               {:error,
                {:invalid_keys, [{3, :malformed}, {4, :unsupported_key_type}, {5, :invalid_key}]}}
    end

    test "cannot parse text containing a private key" do
      public_key = SSHFactory.random_ssh_host_key()

      for header <- ["OPENSSH PRIVATE KEY", "RSA PRIVATE KEY", "EC PRIVATE KEY", "PRIVATE KEY"] do
        input = """
        #{SSHHostKey.to_openssh(public_key)}
        -----BEGIN #{header}-----
        (key material)
        -----END #{header}-----
        """

        assert SSH.parse_ssh_host_keys(input) == {:error, :private_key}
      end
    end
  end

  describe "format_ssh_host_keys/1" do
    test "formats keys one per line" do
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      assert SSH.format_ssh_host_keys([first_key, second_key]) ==
               "#{SSHHostKey.to_openssh(first_key)}\n#{SSHHostKey.to_openssh(second_key)}"
    end

    test "formats no keys as an empty string" do
      assert SSH.format_ssh_host_keys([]) == ""
    end
  end

  describe "stored_ssh_host_keys/1" do
    test "returns the stored keys" do
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      stored =
        "#{SSHHostKey.to_openssh(first_key)}\n#{SSHHostKey.to_openssh(second_key)}"

      assert SSH.stored_ssh_host_keys(stored) == [first_key, second_key]
    end

    test "returns no keys when none are stored" do
      assert SSH.stored_ssh_host_keys(nil) == []
    end

    test "returns no keys when the stored value is invalid" do
      assert SSH.stored_ssh_host_keys("(no keys defined)") == []
    end
  end

  describe "validate_ssh_host_keys/2" do
    test "normalizes valid keys to their stored format" do
      first_key = SSHFactory.random_ssh_host_key()
      second_key = SSHFactory.random_ssh_host_key()

      changeset =
        keys_changeset("""
        # server.example.com:22 SSH-2.0-OpenSSH_9.6p1
        server.example.com #{SSHHostKey.to_openssh(first_key)}

          #{SSHHostKey.to_openssh(second_key)} root@server
        #{SSHHostKey.to_openssh(first_key)} root@server
        """)

      assert SSH.validate_ssh_host_keys(changeset, :keys) == %{
               changeset
               | changes: %{
                   keys:
                     "#{SSHHostKey.to_openssh(first_key)}\n#{SSHHostKey.to_openssh(second_key)}"
                 }
             }
    end

    test "changes a blank value to nil" do
      changeset =
        Changeset.cast(
          {%{keys: SSHFactory.random_ssh_host_keys()}, %{keys: :string}},
          %{keys: " \n\t\n "},
          [:keys],
          empty_values: []
        )

      assert SSH.validate_ssh_host_keys(changeset, :keys) == %{
               changeset
               | changes: %{keys: nil}
             }
    end

    test "does nothing when the field is unchanged or nil" do
      unchanged = Changeset.cast({%{keys: nil}, %{keys: :string}}, %{}, [:keys])
      stored_keys = SSHFactory.random_ssh_host_keys()
      unchanged_stored = Changeset.cast({%{keys: stored_keys}, %{keys: :string}}, %{}, [:keys])

      changed_to_nil =
        Changeset.cast({%{keys: stored_keys}, %{keys: :string}}, %{keys: nil}, [:keys])

      assert {
               SSH.validate_ssh_host_keys(unchanged, :keys),
               SSH.validate_ssh_host_keys(unchanged_stored, :keys),
               SSH.validate_ssh_host_keys(changed_to_nil, :keys)
             } == {unchanged, unchanged_stored, changed_to_nil}
    end

    test "rejects a value without keys" do
      changeset = keys_changeset("# server.example.com:22 SSH-2.0-OpenSSH_9.6p1")

      assert SSH.validate_ssh_host_keys(changeset, :keys) == %{
               changeset
               | valid?: false,
                 errors: [
                   keys:
                     {"must contain at least one SSH public key",
                      [validation: :ssh_host_keys, reason: :no_keys_found]}
                 ]
             }
    end

    test "rejects a value with invalid lines, without showing their contents" do
      valid_key = SSHFactory.random_ssh_host_key()

      changeset =
        keys_changeset("""
        not a key
        #{SSHHostKey.to_openssh(valid_key)}
        ssh-dss AAAAB3NzaC1kc3MAAACBAP
        """)

      assert SSH.validate_ssh_host_keys(changeset, :keys) == %{
               changeset
               | valid?: false,
                 errors: [
                   keys:
                     {"must contain only SSH public keys, one per line (invalid lines: {lines})",
                      [
                        validation: :ssh_host_keys,
                        reason: {:invalid_keys, [{1, :malformed}, {3, :unsupported_key_type}]},
                        lines: "1, 3"
                      ]}
                 ]
             }
    end

    test "rejects a value containing a private key" do
      changeset =
        keys_changeset("""
        -----BEGIN OPENSSH PRIVATE KEY-----
        (key material)
        -----END OPENSSH PRIVATE KEY-----
        """)

      assert SSH.validate_ssh_host_keys(changeset, :keys) == %{
               changeset
               | valid?: false,
                 errors: [
                   keys:
                     {"must not contain a private key: only provide the public keys (the .pub files), and never share a private key",
                      [validation: :ssh_host_keys, reason: :private_key]}
                 ]
             }
    end
  end

  defp keys_changeset(keys),
    do: Changeset.cast({%{keys: nil}, %{keys: :string}}, %{keys: keys}, [:keys])
end
