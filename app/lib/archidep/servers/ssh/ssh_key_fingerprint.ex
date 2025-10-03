defmodule ArchiDep.Servers.SSH.SSHKeyFingerprint do
  @moduledoc """
  A parsed SSH public key fingerprint.
  """

  @enforce_keys [:fingerprint, :key_alg, :raw]
  defstruct [:fingerprint, :key_alg, :raw]

  @type t :: %__MODULE__{
          fingerprint: {:md5, <<_::16>>} | {:sha256, <<_::32>>},
          key_alg: String.t(),
          raw: String.t()
        }

  @type parse_error ::
          :malformed
          | :invalid_md5_fingerprint
          | :invalid_sha256_fingerprint
          | :unknown_fingerprint_format

  @spec fingerprint_human(t()) :: String.t()
  def fingerprint_human(%__MODULE__{fingerprint: {:md5, binary}}),
    do:
      "MD5:" <>
        (binary
         |> Base.encode16(case: :lower)
         |> String.graphemes()
         |> Enum.chunk_every(2)
         |> Enum.map_join(":", &Enum.join/1))

  def fingerprint_human(%__MODULE__{fingerprint: {:sha256, binary}}),
    do:
      "SHA256:" <>
        Base.encode64(binary, padding: false)

  @spec key_algorithm(t()) :: String.t()
  def key_algorithm(%__MODULE__{key_alg: key_alg}), do: key_alg

  @spec match?(t(), String.t()) :: boolean

  def match?(%__MODULE__{fingerprint: {:md5, binary}}, "MD5:" <> fingerprint) do
    case fingerprint |> String.replace(":", "") |> Base.decode16(case: :mixed) do
      {:ok, ^binary} -> true
      _anything_else -> false
    end
  end

  def match?(%__MODULE__{fingerprint: {:sha256, binary}}, "SHA256:" <> fingerprint) do
    case Base.decode64(fingerprint, padding: false) do
      {:ok, ^binary} -> true
      _anything_else -> false
    end
  end

  def match?(_any_fingerprint, _any_string), do: false

  @spec new({:md5, <<_::16>>} | {:sha256, <<_::32>>}, String.t(), String.t()) :: t()
  def new(fingerprint, key_alg, raw) when is_binary(key_alg) and is_binary(raw),
    do: %__MODULE__{
      fingerprint: fingerprint,
      key_alg: key_alg,
      raw: raw
    }

  @doc """
  Parses a single SSH public key fingerprint as output by `ssh-keygen -lf
  <key-file>`.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, parse_error()}
  def parse(fingerprint) when is_binary(fingerprint) do
    with {:ok, fingerprint_string, key_alg, raw} <- parse_ssh_keygen_output_line(fingerprint),
         {:ok, decoded_fingerprint} <- decode_key_fingerprint(fingerprint_string) do
      {:ok, new(decoded_fingerprint, key_alg, raw)}
    end
  end

  @doc """
  Parses a single SSH public key fingerprint in MD5 or SHA256 format.
  """
  @spec parse(String.t(), :md5 | :sha256 | :any) :: {:ok, t()} | {:error, parse_error()}
  def parse(fingerprint, :any) when is_binary(fingerprint) do
    parse(fingerprint)
  end

  def parse(fingerprint, :md5) when is_binary(fingerprint) do
    with {:ok, "MD5:" <> fingerprint_string, key_alg, raw} <-
           parse_ssh_keygen_output_line(fingerprint),
         {:ok, decoded_fingerprint} <- decode_key_fingerprint("MD5:" <> fingerprint_string) do
      {:ok, new(decoded_fingerprint, key_alg, raw)}
    else
      {:ok, _fingerprint_string, _key_alg, _raw} -> {:error, :invalid_md5_fingerprint}
    end
  end

  def parse(fingerprint, :sha256) when is_binary(fingerprint) do
    with {:ok, "SHA256:" <> fingerprint_string, key_alg, raw} <-
           parse_ssh_keygen_output_line(fingerprint),
         {:ok, decoded_fingerprint} <- decode_key_fingerprint("SHA256:" <> fingerprint_string) do
      {:ok, new(decoded_fingerprint, key_alg, raw)}
    else
      {:ok, _fingerprint_string, _key_alg, _raw} -> {:error, :invalid_sha256_fingerprint}
    end
  end

  defp parse_ssh_keygen_output_line(line) do
    case Regex.run(
           ~r"^.*((?:MD5(?::[A-Fa-f0-9]{2})+)|(?:SHA256:[A-Za-z0-9+/]+={0,2})).*\(([^)]+)\).*$",
           line
         ) do
      [_full, fingerprint_string, key_alg] -> {:ok, fingerprint_string, key_alg, line}
      _anything_else -> {:error, :malformed}
    end
  end

  defp decode_key_fingerprint("MD5:" <> fingerprint) do
    case fingerprint |> String.replace(":", "") |> Base.decode16(case: :mixed) do
      {:ok, binary} when byte_size(binary) == 16 -> {:ok, {:md5, binary}}
      _anything_else -> {:error, :invalid_md5_fingerprint}
    end
  end

  defp decode_key_fingerprint("SHA256:" <> fingerprint) do
    case Base.decode64(fingerprint, padding: false) do
      {:ok, binary} when byte_size(binary) == 32 -> {:ok, {:sha256, binary}}
      _anything_else -> {:error, :invalid_sha256_fingerprint}
    end
  end

  defp decode_key_fingerprint(_malformed_fingerprint_string),
    do: {:error, :unknown_fingerprint_format}
end
