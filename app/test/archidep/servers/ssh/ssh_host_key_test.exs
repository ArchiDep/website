defmodule ArchiDep.Servers.SSH.SSHHostKeyTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH.SSHHostKey
  alias ArchiDep.Support.SSHFactory

  describe "parse/1" do
    for key_kind <- [:ed25519, :ecdsa_nistp256, :ecdsa_nistp384, :ecdsa_nistp521, :rsa] do
      test "parses a #{key_kind} key from a .pub file line" do
        key = SSHFactory.random_ssh_host_key(unquote(key_kind))

        assert SSHHostKey.parse("#{key.type} #{encode_key(key)} root@server") == {:ok, key}
      end

      test "parses a #{key_kind} key without a comment" do
        key = SSHFactory.random_ssh_host_key(unquote(key_kind))

        assert SSHHostKey.parse("#{key.type} #{encode_key(key)}") == {:ok, key}
      end

      test "parses a #{key_kind} key from a known_hosts or ssh-keyscan line" do
        key = SSHFactory.random_ssh_host_key(unquote(key_kind))

        assert SSHHostKey.parse("server.example.com,192.0.2.10 #{key.type} #{encode_key(key)}") ==
                 {:ok, key}
      end
    end

    test "parses a key followed by a comment containing spaces" do
      key = SSHFactory.random_ssh_host_key()

      assert SSHHostKey.parse("#{key.type} #{encode_key(key)} the exercise VM's key") ==
               {:ok, key}
    end

    test "parses a key surrounded by whitespace" do
      key = SSHFactory.random_ssh_host_key()

      assert SSHHostKey.parse("  #{key.type}\t#{encode_key(key)}  \r") == {:ok, key}
    end

    test "cannot parse text that is not a public key" do
      key = SSHFactory.random_ssh_host_key()
      encoded_key = encode_key(key)

      assert Enum.map(
               [
                 "",
                 key.type,
                 encoded_key,
                 "hello world",
                 "256 SHA256:V0jnGyjc86bi1R3vTmyML4bwnqc/WVEK+Y0M09I3rWY root@test (ED25519)",
                 "@cert-authority *.example.com #{key.type} #{encoded_key}"
               ],
               &SSHHostKey.parse/1
             ) == List.duplicate({:error, :malformed}, 6)
    end

    test "cannot parse a key of an unsupported type" do
      assert Enum.map(
               [
                 "ssh-dss AAAAB3NzaC1kc3MAAACBAP root@server",
                 "server.example.com ssh-dss AAAAB3NzaC1kc3MAAACBAP",
                 "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5"
               ],
               &SSHHostKey.parse/1
             ) == List.duplicate({:error, :unsupported_key_type}, 3)
    end

    test "cannot parse a key that is not valid base64" do
      assert SSHHostKey.parse("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5!!!!") == {:error, :invalid_key}
    end

    test "cannot parse a truncated key" do
      key = SSHFactory.random_ssh_host_key()
      blob = :ssh_file.encode(key.key, :ssh2_pubkey)
      truncated_blob = binary_part(blob, 0, byte_size(blob) - 4)

      assert SSHHostKey.parse("#{key.type} #{Base.encode64(truncated_blob)}") ==
               {:error, :invalid_key}
    end

    test "cannot parse a key with trailing bytes" do
      key = SSHFactory.random_ssh_host_key()
      blob = :ssh_file.encode(key.key, :ssh2_pubkey)

      assert SSHHostKey.parse("#{key.type} #{Base.encode64(blob <> <<0, 0, 0>>)}") ==
               {:error, :invalid_key}
    end

    test "cannot parse a key whose declared type does not match the type encoded in it" do
      ed25519_key = SSHFactory.random_ssh_host_key(:ed25519)
      nistp256_key = SSHFactory.random_ssh_host_key(:ecdsa_nistp256)

      assert {
               SSHHostKey.parse("ssh-rsa #{encode_key(ed25519_key)}"),
               SSHHostKey.parse("ecdsa-sha2-nistp384 #{encode_key(nistp256_key)}")
             } == {{:error, :invalid_key}, {:error, :invalid_key}}
    end
  end

  # These are real host public keys generated with ssh-keygen, and the expected
  # fingerprints are the output of `ssh-keygen -lf` and `ssh-keygen -E md5 -lf`
  # for the same keys, so they are checked independently of this application.
  describe "fingerprint/2 and algorithm/1" do
    for {line, sha256, md5, algorithm} <- [
          {"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDLOpPWR7r89VjK9kPMhsuqERGVbUi5RZnBlccQnt4e root@test",
           "SHA256:V0jnGyjc86bi1R3vTmyML4bwnqc/WVEK+Y0M09I3rWY",
           "MD5:67:86:ac:3d:e9:46:24:eb:82:5c:af:02:11:58:3b:fb", "ED25519"},
          {"ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLw7xhOu0n7K5DlCoqSwRLA5aZExh4s9fhsf0NELpSrJVnoNHwqfd5LUQdmrq4W8PNcloyilUhidRR/tEP2MfU0= root@test",
           "SHA256:67a0K6R9a0AJjhwKRj30hOTW3oRQLowG02WBwkOtJDQ",
           "MD5:43:01:27:8e:c7:01:bf:60:87:4c:b7:d9:e7:d8:59:cd", "ECDSA"},
          {"ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBGG/5HjgnkqRK3U0fIWzgSI9M90FnxFhjKD/oyrPFQSn4v8o4cyLk9YwdGj6vtEWyO0h2yhRYgurum1sISnfoHM4qMvSotTBrhwpMxSU+bCMcDrIw/4ov4vNnBzgDFSYRw==",
           "SHA256:0aZTeJEc/ke5sI65fcpc70c8hNQiqsSJ7Aukqo9xe2Y",
           "MD5:eb:1e:6c:db:a2:85:ad:15:79:58:0d:37:08:1b:98:b9", "ECDSA"},
          {"ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAAKkThOA1ZUGSvHgC/1TeXi5VUESduV5T8YO6U27rsTzO2N/8Ev0Q2CFvS1pglMzNKZZGzhO1+8qXCkxLaZ7ifP7wAljcG0+hYXDlk+G/EXSuQ9lkZ4nl1dGjJ8xyObdtlDsGrdPf3Hh5rnBh+c6zLBu49qg8RSJ41QpwodVDlbWNP5gQ== root@vm",
           "SHA256:bTn0dq8FS7pnFpFH3+FfYfRR6X8jIDGeY2/Rwh2dkEc",
           "MD5:25:b1:aa:a9:be:e2:ec:12:b2:a5:b9:fe:20:7c:a4:20", "ECDSA"},
          {"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDL6EKznX0xg652E/oWppt3TBYTZlArXmjx6Qs3UOzEWsOpO6xLNvSSBt0P0BZmJihqXq3bWy9/Ino+YocJlLeaorIZf5c6Tmrtp/Mnji5td/lxA8+EH47EHcpAkYPA5sg88dM/+pzETBd/75udFzg8RiFG4nnHENfdGgBT3arZ1hR9b+i6CLPiQPGTbrOH3n4D3WH56Kza/50FzslJwK3M7MC3zJ5dakhJBEfxkBQXeWG/oHNJbVRQGZ+b47sDViKnjswXnID3x3413YmxNy87YWmGpxkwGzldanSJwophFbiBszJjh84JdPvEMQyCxex0i82tEp0FC1UmglZfSZzYPvxWdjOUcke8SSh0H+u5pOYqdbuirQTQrhuaoQkLkaruDOQYqX4ycIY10KihOdSfJUnj6JqsyMGDY6SAQMFKACIf/8EMVug0snRDVbCqjz598EQeIdJNXhacaGFhUy8GittwS0gy4IX4TPLo/sF9Hrh134BwF7MkhbCuGRZxjvM= root@test",
           "SHA256:MuGqo9E4F5bUOCqB6JCrQFVY11zHvwgREoOiVZGSx5k",
           "MD5:c9:68:24:63:9a:79:76:e1:79:5f:3e:d7:a1:4c:df:95", "RSA"}
        ] do
      test "describes a #{line |> String.split() |> hd()} key like ssh-keygen" do
        {:ok, key} = SSHHostKey.parse(unquote(line))

        assert {
                 SSHHostKey.fingerprint(key, :sha256),
                 SSHHostKey.fingerprint(key, :md5),
                 SSHHostKey.algorithm(key)
               } == {unquote(sha256), unquote(md5), unquote(algorithm)}
      end
    end
  end

  describe "to_openssh/1" do
    test "formats a key as its type and base64 encoding" do
      key = SSHFactory.random_ssh_host_key()

      assert SSHHostKey.to_openssh(key) == "#{key.type} #{encode_key(key)}"
    end

    test "formats a key that parses back to the same key, without the comment or hosts it was parsed with" do
      key = SSHFactory.random_ssh_host_key()

      {:ok, parsed_key} =
        SSHHostKey.parse("server.example.com #{key.type} #{encode_key(key)} root@server")

      assert parsed_key |> SSHHostKey.to_openssh() |> SSHHostKey.parse() == {:ok, key}
    end
  end

  defp encode_key(%SSHHostKey{key: key}),
    do: key |> :ssh_file.encode(:ssh2_pubkey) |> Base.encode64()
end
