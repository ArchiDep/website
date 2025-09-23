defmodule ArchiDep.Support.SSHFactory do
  @moduledoc """
  Test fixtures for SSH-related data.
  """

  use ArchiDep.Support, :factory

  @ssh_host_key_algs_and_sizes [{"RSA", 3072}, {"ECDSA", 256}, {"ED25519", 256}]

  @spec random_ssh_host_key_fingerprint_digest() :: String.t()
  def random_ssh_host_key_fingerprint_digest do
    {digest_alg, digest} =
      if bool() do
        {"SHA256", 32 |> Faker.random_bytes() |> Base.encode64(padding: false)}
      else
        {"MD5",
         16
         |> Faker.random_bytes()
         |> Base.encode16(case: :lower)
         |> String.graphemes()
         |> Enum.chunk_every(2)
         |> Enum.map_join(":", &Enum.join/1)}
      end

    "#{digest_alg}:#{digest}"
  end

  @spec random_ssh_host_key_fingerprint_string() :: String.t()
  def random_ssh_host_key_fingerprint_string do
    {alg, size} = Enum.random(@ssh_host_key_algs_and_sizes)
    "#{size} #{random_ssh_host_key_fingerprint_digest()} root@server (#{alg})"
  end
end
