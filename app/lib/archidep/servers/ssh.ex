defmodule ArchiDep.Servers.SSH do
  @moduledoc """
  Functions to retrieve SSH connection parameters for servers.
  """

  alias ArchiDep.Servers.SSH.SSHKeyFingerprint

  @spec parse_ssh_host_key_fingerprints(String.t()) ::
          {:ok, list(SSHKeyFingerprint.t()), list({String.t(), SSHKeyFingerprint.parse_error()})}
          | {:error,
             :no_keys_found | {:invalid_keys, list({String.t(), SSHKeyFingerprint.parse_error()})}}
  def parse_ssh_host_key_fingerprints(fingerprints) when is_binary(fingerprints) do
    non_empty_lines =
      fingerprints |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))

    results = Enum.map(non_empty_lines, &{&1, SSHKeyFingerprint.parse(&1)})

    valid_results =
      Enum.flat_map(results, fn
        {_line, {:ok, fingerprint}} -> [fingerprint]
        {_line, {:error, _reason}} -> []
      end)

    invalid_results =
      results
      |> Enum.filter(&match?({_line, {:error, _reason}}, &1))
      |> Enum.map(fn {line, {:error, reason}} -> {line, reason} end)

    case {non_empty_lines, valid_results, invalid_results} do
      {[], _valid, _invalid} -> {:error, :no_keys_found}
      {_lines, [], invalid} -> {:error, {:invalid_keys, invalid}}
      {_lines, valid, invalid} -> {:ok, valid, invalid}
    end
  end

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
