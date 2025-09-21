defmodule ArchiDep.Servers.SSH.SSHKeyFingerprintTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH.SSHKeyFingerprint

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
end
