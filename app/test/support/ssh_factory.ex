defmodule ArchiDep.Support.SSHFactory do
  @moduledoc """
  Test fixtures for SSH-related data.
  """

  use ArchiDep.Support, :factory

  @ssh_host_key_algs_and_sizes [{"RSA", 3072}, {"ECDSA", 256}, {"ED25519", 256}]

  @spec random_ssh_host_key_fingerprint_digest() :: String.t()
  def random_ssh_host_key_fingerprint_digest do
    if bool() do
      random_ssh_host_key_fingerprint_digest(:md5)
    else
      random_ssh_host_key_fingerprint_digest(:sha256)
    end
  end

  @spec random_ssh_host_key_fingerprint_digest(:md5 | :sha256) :: String.t()

  def random_ssh_host_key_fingerprint_digest(:md5) do
    digest =
      16
      |> Faker.random_bytes()
      |> Base.encode16(case: :lower)
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map_join(":", &Enum.join/1)

    "MD5:#{digest}"
  end

  def random_ssh_host_key_fingerprint_digest(:sha256) do
    digest = 32 |> Faker.random_bytes() |> Base.encode64(padding: false)
    "SHA256:#{digest}"
  end

  @spec random_ssh_host_key_fingerprint_string() :: String.t()
  def random_ssh_host_key_fingerprint_string() do
    if bool() do
      random_ssh_host_key_fingerprint_string(:md5)
    else
      random_ssh_host_key_fingerprint_string(:sha256)
    end
  end

  @spec random_ssh_host_key_fingerprint_string(:md5 | :sha256) :: String.t()
  def random_ssh_host_key_fingerprint_string(digest_alg) do
    {alg, size} = Enum.random(@ssh_host_key_algs_and_sizes)
    "#{size} #{random_ssh_host_key_fingerprint_digest(digest_alg)} root@server (#{alg})"
  end
end
