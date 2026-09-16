defmodule ArchiDep.Servers.SSH do
  @moduledoc """
  Functions to retrieve SSH connection parameters for servers.
  """

  import Ecto.Changeset
  alias ArchiDep.Servers.SSH.SSHHostKey
  alias Ecto.Changeset

  @private_key_header ~r/-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/

  @doc """
  Parses SSH host public keys, one per line, as printed by `cat
  /etc/ssh/ssh_host_*_key.pub` (or `ssh-keyscan`). Blank lines and `#` comment
  lines are ignored, and duplicate keys are only kept once.

  Every other line must be a valid public key: these keys are what a connection
  to a server is checked against, so a value that is only partly valid is
  rejected rather than trusted for its valid part. Invalid lines are identified
  by their 1-based line number, never by their content, since a line that is not
  a public key may be something that should not be shown back, such as part of a
  private key.
  """
  @spec parse_ssh_host_keys(String.t()) ::
          {:ok, list(SSHHostKey.t())}
          | {:error,
             :no_keys_found
             | :private_key
             | {:invalid_keys, list({pos_integer(), SSHHostKey.parse_error()})}}
  def parse_ssh_host_keys(keys) when is_binary(keys) do
    if String.match?(keys, @private_key_header) do
      {:error, :private_key}
    else
      keys
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.map(fn {line, number} -> {String.trim(line), number} end)
      |> Enum.reject(fn {line, _number} -> line == "" or String.starts_with?(line, "#") end)
      |> Enum.map(fn {line, number} -> {number, SSHHostKey.parse(line)} end)
      |> parse_results()
    end
  end

  @doc """
  Formats SSH host public keys as stored: one `<type> <base64>` line per key.
  """
  @spec format_ssh_host_keys(list(SSHHostKey.t())) :: String.t()
  def format_ssh_host_keys(keys) when is_list(keys),
    do: Enum.map_join(keys, "\n", &SSHHostKey.to_openssh/1)

  @doc """
  Validates a changeset field holding SSH host public keys (see
  `parse_ssh_host_keys/1`), and normalizes a valid value to the stored format
  (see `format_ssh_host_keys/1`). A blank value is changed to `nil`.
  """
  @spec validate_ssh_host_keys(Changeset.t(), atom()) :: Changeset.t()
  def validate_ssh_host_keys(changeset, field) when is_atom(field) do
    case fetch_change(changeset, field) do
      {:ok, value} when is_binary(value) ->
        if String.trim(value) == "" do
          put_change(changeset, field, nil)
        else
          put_parsed_ssh_host_keys(changeset, field, parse_ssh_host_keys(value))
        end

      _no_change_or_nil ->
        changeset
    end
  end

  @doc """
  Returns the SSH host public keys stored in the specified value, or an empty
  list if there are none.
  """
  @spec stored_ssh_host_keys(String.t() | nil) :: list(SSHHostKey.t())
  def stored_ssh_host_keys(nil), do: []

  def stored_ssh_host_keys(keys) when is_binary(keys) do
    case parse_ssh_host_keys(keys) do
      {:ok, parsed_keys} -> parsed_keys
      {:error, _reason} -> []
    end
  end

  defp parse_results([]), do: {:error, :no_keys_found}

  defp parse_results(results) do
    case Enum.filter(results, &match?({_number, {:error, _reason}}, &1)) do
      [] ->
        {:ok,
         results
         |> Enum.map(fn {_number, {:ok, key}} -> key end)
         |> Enum.uniq_by(&SSHHostKey.to_openssh/1)}

      invalid ->
        {:error,
         {:invalid_keys, Enum.map(invalid, fn {number, {:error, reason}} -> {number, reason} end)}}
    end
  end

  defp put_parsed_ssh_host_keys(changeset, field, {:ok, keys}),
    do: put_change(changeset, field, format_ssh_host_keys(keys))

  defp put_parsed_ssh_host_keys(changeset, field, {:error, :no_keys_found}),
    do:
      add_error(changeset, field, "must contain at least one SSH public key",
        validation: :ssh_host_keys,
        reason: :no_keys_found
      )

  defp put_parsed_ssh_host_keys(changeset, field, {:error, :private_key}),
    do:
      add_error(
        changeset,
        field,
        "must not contain a private key: only provide the public keys (the .pub files), and never share a private key",
        validation: :ssh_host_keys,
        reason: :private_key
      )

  defp put_parsed_ssh_host_keys(changeset, field, {:error, {:invalid_keys, invalid}}),
    do:
      add_error(
        changeset,
        field,
        "must contain only SSH public keys, one per line (invalid lines: {lines})",
        validation: :ssh_host_keys,
        reason: {:invalid_keys, invalid},
        lines: Enum.map_join(invalid, ", ", &elem(&1, 0))
      )

  @spec ssh_dir() :: String.t()
  def ssh_dir, do: Path.dirname(ssh_private_key_file())

  @spec ssh_public_key() :: String.t()
  def ssh_public_key,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:ssh_public_key)

  @spec ssh_private_key_file() :: String.t()
  def ssh_private_key_file,
    do:
      :archidep
      |> Application.fetch_env!(:servers)
      |> Keyword.fetch!(:ssh_private_key_file)
end
