defmodule ArchiDep.Servers.SSH.SSHKeyFingerprintTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH.SSHKeyFingerprint

  @md5_line "1024 MD5:bd:2a:99:f8:ec:a6:c8:46:ff:9d:c7:2e:ae:15:6e:50 root@server (RSA)"
  @md5_fingerprint {:md5,
                    <<189, 42, 153, 248, 236, 166, 200, 70, 255, 157, 199, 46, 174, 21, 110, 80>>}
  @sha256_line "256 SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w root@server (ED25519)"
  @sha256_fingerprint {:sha256,
                       <<139, 173, 118, 81, 139, 221, 15, 6, 73, 249, 78, 106, 115, 183, 27, 161,
                         60, 64, 244, 11, 255, 139, 126, 15, 213, 28, 141, 136, 57, 19, 95, 252>>}

  test "match a mixed-case md5 fingerprint with colons" do
    fp =
      SSHKeyFingerprint.new(
        {:md5, <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>},
        "rsa",
        "raw"
      )

    assert SSHKeyFingerprint.match?(fp, "MD5:01:02:03:04:05:06:07:08:09:0A:0b:0C:0D:0e:0F:10")
  end

  test "match a mixed-case md5 fingerprint without colons" do
    fp =
      SSHKeyFingerprint.new(
        {:md5, <<16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1>>},
        "ecdsa",
        "raw"
      )

    assert SSHKeyFingerprint.match?(fp, "MD5:100f0E0D0C0B0a090807060504030201")
  end

  test "do not match a different md5 fingerprint" do
    fp = SSHKeyFingerprint.new({:md5, <<0::128>>}, "dss", "raw")
    assert SSHKeyFingerprint.match?(fp, "MD5:deadbeefdeadbeefdeadbeefdeadbeef") == false
  end

  test "match a sha256 fingerprint" do
    fp =
      SSHKeyFingerprint.new(
        {:sha256,
         <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
           25, 26, 27, 28, 29, 30, 31, 32>>},
        "rsa",
        "raw"
      )

    assert SSHKeyFingerprint.match?(fp, "SHA256:AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA")
  end

  test "match a sha256 fingerprint with padding" do
    fp =
      SSHKeyFingerprint.new(
        {:sha256,
         <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
           25, 26, 27, 28, 29, 30, 31, 32>>},
        "rsa",
        "raw"
      )

    assert SSHKeyFingerprint.match?(fp, "SHA256:AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=")
  end

  test "do not match a different sha256 fingerprint" do
    fp = SSHKeyFingerprint.new({:sha256, <<0::256>>}, "ecdsa", "raw")

    assert SSHKeyFingerprint.match?(fp, "SHA256:iY64XBzK3PHK/rlU6mXqUhSws95/jNuCIO1mSbKbhtk") ==
             false
  end

  describe "parse/1" do
    test "parse an MD5 fingerprint line" do
      assert SSHKeyFingerprint.parse(@md5_line) ==
               {:ok,
                %SSHKeyFingerprint{fingerprint: @md5_fingerprint, key_alg: "RSA", raw: @md5_line}}
    end

    test "parse a SHA256 fingerprint line" do
      assert SSHKeyFingerprint.parse(@sha256_line) ==
               {:ok,
                %SSHKeyFingerprint{
                  fingerprint: @sha256_fingerprint,
                  key_alg: "ED25519",
                  raw: @sha256_line
                }}
    end

    test "reject an MD5 fingerprint that decodes to the wrong length" do
      assert SSHKeyFingerprint.parse("1024 MD5:bd:2a root@server (RSA)") ==
               {:error, :invalid_md5_fingerprint}
    end

    test "reject a SHA256 fingerprint that decodes to the wrong length" do
      assert SSHKeyFingerprint.parse("256 SHA256:YWJj root@server (ED25519)") ==
               {:error, :invalid_sha256_fingerprint}
    end

    test "reject a malformed line" do
      assert SSHKeyFingerprint.parse("this is not a fingerprint") == {:error, :malformed}
    end
  end

  # `parse/2` with `:md5` or `:sha256` raises on a fully malformed line (the SSH
  # host key fingerprint parsing crash documented in docs/known-issues.md), so
  # malformed input is exercised only through the graceful `:any`/`parse/1`
  # path. The `:unknown_fingerprint_format` decode error is unreachable through
  # `parse`: the parser regex only ever yields an `MD5:` or `SHA256:` prefix.
  describe "parse/2" do
    test "parse an MD5 fingerprint in any format" do
      assert SSHKeyFingerprint.parse(@md5_line, :any) ==
               {:ok,
                %SSHKeyFingerprint{fingerprint: @md5_fingerprint, key_alg: "RSA", raw: @md5_line}}
    end

    test "parse a SHA256 fingerprint in any format" do
      assert SSHKeyFingerprint.parse(@sha256_line, :any) ==
               {:ok,
                %SSHKeyFingerprint{
                  fingerprint: @sha256_fingerprint,
                  key_alg: "ED25519",
                  raw: @sha256_line
                }}
    end

    test "reject a malformed line in any format" do
      assert SSHKeyFingerprint.parse("this is not a fingerprint", :any) == {:error, :malformed}
    end

    test "parse an MD5 fingerprint when requiring MD5" do
      assert SSHKeyFingerprint.parse(@md5_line, :md5) ==
               {:ok,
                %SSHKeyFingerprint{fingerprint: @md5_fingerprint, key_alg: "RSA", raw: @md5_line}}
    end

    test "reject a SHA256 fingerprint when requiring MD5" do
      assert SSHKeyFingerprint.parse(@sha256_line, :md5) == {:error, :invalid_md5_fingerprint}
    end

    test "parse a SHA256 fingerprint when requiring SHA256" do
      assert SSHKeyFingerprint.parse(@sha256_line, :sha256) ==
               {:ok,
                %SSHKeyFingerprint{
                  fingerprint: @sha256_fingerprint,
                  key_alg: "ED25519",
                  raw: @sha256_line
                }}
    end

    test "reject an MD5 fingerprint when requiring SHA256" do
      assert SSHKeyFingerprint.parse(@md5_line, :sha256) == {:error, :invalid_sha256_fingerprint}
    end
  end

  describe "fingerprint_human/1" do
    test "format an MD5 fingerprint as lowercase colon-separated hex" do
      fp = SSHKeyFingerprint.new(@md5_fingerprint, "RSA", "raw")

      assert SSHKeyFingerprint.fingerprint_human(fp) ==
               "MD5:bd:2a:99:f8:ec:a6:c8:46:ff:9d:c7:2e:ae:15:6e:50"
    end

    test "format a SHA256 fingerprint as unpadded base64" do
      fp = SSHKeyFingerprint.new(@sha256_fingerprint, "ED25519", "raw")

      assert SSHKeyFingerprint.fingerprint_human(fp) ==
               "SHA256:i612UYvdDwZJ+U5qc7cboTxA9Av/i34P1RyNiDkTX/w"
    end
  end

  describe "key_algorithm/1" do
    test "return the key algorithm" do
      fp = SSHKeyFingerprint.new(@md5_fingerprint, "RSA", "raw")
      assert SSHKeyFingerprint.key_algorithm(fp) == "RSA"
    end
  end
end
