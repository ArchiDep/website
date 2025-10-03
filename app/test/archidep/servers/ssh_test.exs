defmodule ArchiDep.Servers.SSHTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint

  test "parse SSH host key fingerprints as output by 'ssh-keygen -lf <key-file>'" do
    valid_fingerprints = """
    3072 SHA256:vXen05cgbefc88jou2yR7I7wp0aBahoNd40anc1qfTY root@server (RSA)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w root@server (ED25519)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w= root@server (ED25519)
    256 SHA256:cj8pfUeXA0lNxOgZI/g1EU4oE6ofhOtscjIsuGiRhqk root@server (ECDSA)
    1024 MD5:bd:2a:99:f8:ec:a6:c8:46:ff:9d:c7:2e:ae:15:6e:50 root@server (RSA)
    1024 MD5:86:0C:54:D5:06:D2:82:84:F1:F8:E6:53:BF:30:88:FD root@server (RSA)
    """

    [rsa_line, ed25519_line, padded_ed25519_line, ecdsa_line, old_rsa_line, old_rsa_line2] =
      String.split(valid_fingerprints, "\n", trim: true)

    assert SSH.parse_ssh_host_key_fingerprints(valid_fingerprints) ==
             {:ok,
              [
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<189, 119, 167, 211, 151, 32, 109, 231, 220, 243, 200, 232, 187, 108, 145,
                       236, 142, 240, 167, 70, 129, 106, 26, 13, 119, 141, 26, 157, 205, 106, 125,
                       54>>},
                  key_alg: "RSA",
                  raw: rsa_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<139, 173, 118, 81, 139, 221, 15, 6, 73, 249, 78, 106, 115, 183, 27, 161,
                       60, 64, 244, 11, 255, 139, 126, 15, 213, 28, 141, 136, 57, 19, 95, 252>>},
                  key_alg: "ED25519",
                  raw: ed25519_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<139, 173, 118, 81, 139, 221, 15, 6, 73, 249, 78, 106, 115, 183, 27, 161,
                       60, 64, 244, 11, 255, 139, 126, 15, 213, 28, 141, 136, 57, 19, 95, 252>>},
                  key_alg: "ED25519",
                  raw: padded_ed25519_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<114, 63, 41, 125, 71, 151, 3, 73, 77, 196, 232, 25, 35, 248, 53, 17, 78,
                       40, 19, 170, 31, 132, 235, 108, 114, 50, 44, 184, 104, 145, 134, 169>>},
                  key_alg: "ECDSA",
                  raw: ecdsa_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:md5,
                     <<189, 42, 153, 248, 236, 166, 200, 70, 255, 157, 199, 46, 174, 21, 110, 80>>},
                  key_alg: "RSA",
                  raw: old_rsa_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:md5,
                     <<134, 12, 84, 213, 6, 210, 130, 132, 241, 248, 230, 83, 191, 48, 136, 253>>},
                  key_alg: "RSA",
                  raw: old_rsa_line2
                }
              ], []}
  end

  test "parse SSH MD5 host key fingerprints as output by 'ssh-keygen -lf <key-file>'" do
    valid_fingerprints = """
    1024 MD5:bd:2a:99:f8:ec:a6:c8:46:ff:9d:c7:2e:ae:15:6e:50 root@server (RSA)
    1024 MD5:86:0C:54:D5:06:D2:82:84:F1:F8:E6:53:BF:30:88:FD root@server (RSA)
    """

    [old_rsa_line, old_rsa_line2] = String.split(valid_fingerprints, "\n", trim: true)

    assert SSH.parse_ssh_host_key_fingerprints(valid_fingerprints, :md5) ==
             {:ok,
              [
                %SSHKeyFingerprint{
                  fingerprint:
                    {:md5,
                     <<189, 42, 153, 248, 236, 166, 200, 70, 255, 157, 199, 46, 174, 21, 110, 80>>},
                  key_alg: "RSA",
                  raw: old_rsa_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:md5,
                     <<134, 12, 84, 213, 6, 210, 130, 132, 241, 248, 230, 83, 191, 48, 136, 253>>},
                  key_alg: "RSA",
                  raw: old_rsa_line2
                }
              ], []}
  end

  test "parse SSH SHA256 host key fingerprints as output by 'ssh-keygen -lf <key-file>'" do
    valid_fingerprints = """
    3072 SHA256:vXen05cgbefc88jou2yR7I7wp0aBahoNd40anc1qfTY root@server (RSA)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w root@server (ED25519)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w= root@server (ED25519)
    256 SHA256:cj8pfUeXA0lNxOgZI/g1EU4oE6ofhOtscjIsuGiRhqk root@server (ECDSA)
    """

    [rsa_line, ed25519_line, padded_ed25519_line, ecdsa_line] =
      String.split(valid_fingerprints, "\n", trim: true)

    assert SSH.parse_ssh_host_key_fingerprints(valid_fingerprints, :sha256) ==
             {:ok,
              [
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<189, 119, 167, 211, 151, 32, 109, 231, 220, 243, 200, 232, 187, 108, 145,
                       236, 142, 240, 167, 70, 129, 106, 26, 13, 119, 141, 26, 157, 205, 106, 125,
                       54>>},
                  key_alg: "RSA",
                  raw: rsa_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<139, 173, 118, 81, 139, 221, 15, 6, 73, 249, 78, 106, 115, 183, 27, 161,
                       60, 64, 244, 11, 255, 139, 126, 15, 213, 28, 141, 136, 57, 19, 95, 252>>},
                  key_alg: "ED25519",
                  raw: ed25519_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<139, 173, 118, 81, 139, 221, 15, 6, 73, 249, 78, 106, 115, 183, 27, 161,
                       60, 64, 244, 11, 255, 139, 126, 15, 213, 28, 141, 136, 57, 19, 95, 252>>},
                  key_alg: "ED25519",
                  raw: padded_ed25519_line
                },
                %SSHKeyFingerprint{
                  fingerprint:
                    {:sha256,
                     <<114, 63, 41, 125, 71, 151, 3, 73, 77, 196, 232, 25, 35, 248, 53, 17, 78,
                       40, 19, 170, 31, 132, 235, 108, 114, 50, 44, 184, 104, 145, 134, 169>>},
                  key_alg: "ECDSA",
                  raw: ecdsa_line
                }
              ], []}
  end

  test "cannot parse SSH MD5 host key fingerprints as SHA256 ingerprints" do
    valid_fingerprints = """
    1024 MD5:bd:2a:99:f8:ec:a6:c8:46:ff:9d:c7:2e:ae:15:6e:50 root@server (RSA)
    1024 MD5:86:0C:54:D5:06:D2:82:84:F1:F8:E6:53:BF:30:88:FD root@server (RSA)
    """

    [old_rsa_line, old_rsa_line2] = String.split(valid_fingerprints, "\n", trim: true)

    assert SSH.parse_ssh_host_key_fingerprints(valid_fingerprints, :sha256) ==
             {:error,
              {:invalid_keys,
               [
                 {old_rsa_line, :invalid_sha256_fingerprint},
                 {old_rsa_line2, :invalid_sha256_fingerprint}
               ]}}
  end

  test "cannot parse SSH SHA256 host key fingerprints as MD5" do
    valid_fingerprints = """
    3072 SHA256:vXen05cgbefc88jou2yR7I7wp0aBahoNd40anc1qfTY root@server (RSA)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w root@server (ED25519)
    256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w= root@server (ED25519)
    256 SHA256:cj8pfUeXA0lNxOgZI/g1EU4oE6ofhOtscjIsuGiRhqk root@server (ECDSA)
    """

    [rsa_line, ed25519_line, padded_ed25519_line, ecdsa_line] =
      String.split(valid_fingerprints, "\n", trim: true)

    assert SSH.parse_ssh_host_key_fingerprints(valid_fingerprints, :md5) ==
             {:error,
              {:invalid_keys,
               [
                 {rsa_line, :invalid_md5_fingerprint},
                 {ed25519_line, :invalid_md5_fingerprint},
                 {padded_ed25519_line, :invalid_md5_fingerprint},
                 {ecdsa_line, :invalid_md5_fingerprint}
               ]}}
  end

  test "cannot parse invalid SSH host key fingerprints" do
    invalid_keys =
      Enum.join(
        [
          "not-a-key",
          " ",
          "another-bad-key",
          "SHA256:almostakey but no key algorithm",
          "256 MD5:00:01:02 root@too-short-md5 (ECDSA)",
          "256 MD5:00:01:02:03:04:05:06:07:08:09:0a:0b:0c root@too-long-md5 (ECDSA)",
          "256 SHA256:tooshortbase64 root@server (ED25519)",
          "256 SHA256:toolongbase64bZFC321GueBNa7sKT7UPld2Zk5bCZRAI5EjgT9Up2vU root@server (ED25519)"
        ],
        "\n"
      )

    assert SSH.parse_ssh_host_key_fingerprints(invalid_keys) ==
             {:error,
              {:invalid_keys,
               [
                 {"not-a-key", :malformed},
                 {"another-bad-key", :malformed},
                 {"SHA256:almostakey but no key algorithm", :malformed},
                 {"256 MD5:00:01:02 root@too-short-md5 (ECDSA)", :invalid_md5_fingerprint},
                 {"256 MD5:00:01:02:03:04:05:06:07:08:09:0a:0b:0c root@too-long-md5 (ECDSA)",
                  :invalid_md5_fingerprint},
                 {"256 SHA256:tooshortbase64 root@server (ED25519)", :invalid_sha256_fingerprint},
                 {"256 SHA256:toolongbase64bZFC321GueBNa7sKT7UPld2Zk5bCZRAI5EjgT9Up2vU root@server (ED25519)",
                  :invalid_sha256_fingerprint}
               ]}}
  end

  test "cannot parse blank text as SSH host key fingerprints" do
    for blank_input <- ["", "   ", "\n", "\n\n", " \n ", "\n \n"] do
      assert SSH.parse_ssh_host_key_fingerprints(blank_input) == {:error, :no_keys_found}
    end
  end
end
