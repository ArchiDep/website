defmodule ArchiDep.Support.SSHFactory do
  @moduledoc """
  Test fixtures for SSH-related data.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHHostKey

  @ed25519_oid {1, 3, 101, 112}

  @doc """
  Generates a random SSH host public key, either Ed25519 or ECDSA with the
  NIST P-256 curve (the key types that are cheapest to generate).
  """
  @spec random_ssh_host_key() :: SSHHostKey.t()
  def random_ssh_host_key do
    if bool() do
      random_ssh_host_key(:ed25519)
    else
      random_ssh_host_key(:ecdsa)
    end
  end

  @spec random_ssh_host_key(
          :ed25519
          | :ecdsa
          | :ecdsa_nistp256
          | :ecdsa_nistp384
          | :ecdsa_nistp521
          | :rsa
        ) :: SSHHostKey.t()
  def random_ssh_host_key(:ed25519) do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    %SSHHostKey{
      type: "ssh-ed25519",
      key: {{:ECPoint, public_key}, {:namedCurve, @ed25519_oid}}
    }
  end

  def random_ssh_host_key(:ecdsa), do: random_ssh_host_key(:ecdsa_nistp256)
  def random_ssh_host_key(:ecdsa_nistp256), do: random_ecdsa_host_key("nistp256", :secp256r1)
  def random_ssh_host_key(:ecdsa_nistp384), do: random_ecdsa_host_key("nistp384", :secp384r1)
  def random_ssh_host_key(:ecdsa_nistp521), do: random_ecdsa_host_key("nistp521", :secp521r1)

  def random_ssh_host_key(:rsa) do
    {:RSAPrivateKey, _version, modulus, public_exponent, _private_exponent, _prime1, _prime2,
     _exponent1, _exponent2, _coefficient, _other_prime_infos} =
      :public_key.generate_key({:rsa, 2048, 65_537})

    %SSHHostKey{type: "ssh-rsa", key: {:RSAPublicKey, modulus, public_exponent}}
  end

  @doc """
  Generates between 1 and 3 random SSH host public keys, formatted as they are
  stored.
  """
  @spec random_ssh_host_keys() :: String.t()
  def random_ssh_host_keys,
    do:
      1
      |> Range.new(Faker.random_between(1, 3))
      |> Enum.map(fn _n -> random_ssh_host_key() end)
      |> SSH.format_ssh_host_keys()

  @doc """
  Generates a random SHA256 SSH host key fingerprint in the format of `ssh-keygen
  -l`, e.g. to simulate a key presented by a server that does not match any known
  key.
  """
  @spec random_ssh_host_key_fingerprint() :: String.t()
  def random_ssh_host_key_fingerprint,
    do: "SHA256:#{32 |> Faker.random_bytes() |> Base.encode64(padding: false)}"

  defp random_ecdsa_host_key(ssh_curve_name, curve) do
    {:ECPrivateKey, _version, _private_key, parameters, public_key, _attributes} =
      :public_key.generate_key({:namedCurve, curve})

    %SSHHostKey{type: "ecdsa-sha2-#{ssh_curve_name}", key: {{:ECPoint, public_key}, parameters}}
  end
end
