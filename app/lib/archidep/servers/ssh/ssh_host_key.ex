defmodule ArchiDep.Servers.SSH.SSHHostKey do
  @moduledoc """
  A parsed SSH host public key.

  A key is parsed from one line in any of the formats a host public key is
  usually found in: the contents of a `/etc/ssh/ssh_host_*_key.pub` file
  (`<type> <base64> [comment]`), or a `known_hosts` or `ssh-keyscan` line
  (`<hosts> <type> <base64>`). The comment and the hosts are discarded: the key
  is stored and rendered as `<type> <base64>`.
  """

  @enforce_keys [:type, :key]
  defstruct [:type, :key]

  @type t :: %__MODULE__{
          type: String.t(),
          key: :public_key.public_key()
        }

  @type parse_error :: :malformed | :unsupported_key_type | :invalid_key

  # The key algorithms ssh-keygen generates host keys for on current systems,
  # mapped to the name it gives them in `ssh-keygen -l` output and in the
  # warning shown by an SSH client connecting for the first time.
  @key_algorithms %{
    "ssh-ed25519" => "ED25519",
    "ecdsa-sha2-nistp256" => "ECDSA",
    "ecdsa-sha2-nistp384" => "ECDSA",
    "ecdsa-sha2-nistp521" => "ECDSA",
    "ssh-rsa" => "RSA"
  }

  @supported_types Map.keys(@key_algorithms)

  @spec parse(String.t()) :: {:ok, t()} | {:error, parse_error()}
  def parse(line) when is_binary(line) do
    case String.split(line) do
      [type, encoded_key | _comment] when type in @supported_types ->
        decode(type, encoded_key)

      [_hosts, type, encoded_key | _comment] when type in @supported_types ->
        decode(type, encoded_key)

      [first, second | _rest] ->
        if key_type?(first) or key_type?(second) do
          {:error, :unsupported_key_type}
        else
          {:error, :malformed}
        end

      _anything_else ->
        {:error, :malformed}
    end
  end

  @doc """
  Returns the fingerprint of the key in the same format as `ssh-keygen -l`,
  e.g. `SHA256:<base64>` or `MD5:<hex>:<hex>:...`.
  """
  @spec fingerprint(t(), :sha256 | :md5) :: String.t()
  def fingerprint(%__MODULE__{key: key}, digest_alg) when digest_alg in [:sha256, :md5],
    do: digest_alg |> :ssh.hostkey_fingerprint(key) |> to_string()

  @doc """
  Returns the name of the key's algorithm as `ssh-keygen -l` shows it, e.g.
  `ED25519`.
  """
  @spec algorithm(t()) :: String.t()
  def algorithm(%__MODULE__{type: type}), do: Map.fetch!(@key_algorithms, type)

  @spec to_openssh(t()) :: String.t()
  def to_openssh(%__MODULE__{type: type, key: key}),
    do: "#{type} #{key |> :ssh_file.encode(:ssh2_pubkey) |> Base.encode64()}"

  # Any other algorithm, e.g. ssh-dss, or a key held in a security key
  # (sk-ssh-ed25519@openssh.com), which a host key never is.
  defp key_type?(token), do: String.match?(token, ~r/\A(?:ssh|ecdsa|sk)-[a-z0-9@.\-]+\z/)

  # The key blob is checked strictly rather than trusting :ssh_file's decoding
  # of the text form, which ignores trailing bytes and does not check that the
  # type written before the key is the one encoded in it. Re-encoding the decoded
  # key must give back exactly the blob that was provided.
  defp decode(type, encoded_key) do
    with {:ok, blob} <- Base.decode64(encoded_key),
         <<type_length::32, ^type::binary-size(type_length), _rest::binary>> <- blob,
         key = decode_blob(blob),
         true <- valid_key?(type, key),
         ^blob <- :ssh_file.encode(key, :ssh2_pubkey) do
      {:ok, %__MODULE__{type: type, key: key}}
    else
      _anything_else -> {:error, :invalid_key}
    end
  end

  # :ssh_file.decode/2 raises rather than returning an error for some malformed
  # blobs, e.g. a truncated one.
  defp decode_blob(blob) do
    :ssh_file.decode(blob, :ssh2_pubkey)
  rescue
    _error -> {:error, :invalid_key}
  end

  defp valid_key?("ssh-ed25519", {{:ECPoint, point}, {:namedCurve, _oid}}),
    do: byte_size(point) == 32

  defp valid_key?("ecdsa-sha2-" <> _curve, {{:ECPoint, point}, {:namedCurve, _oid}}),
    do: byte_size(point) > 0

  defp valid_key?("ssh-rsa", {:RSAPublicKey, modulus, exponent}),
    do: modulus > 0 and exponent > 0

  defp valid_key?(_type, _key), do: false
end
