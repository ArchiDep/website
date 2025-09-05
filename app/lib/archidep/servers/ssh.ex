defmodule ArchiDep.Servers.SSH do
  @moduledoc """
  Functions to retrieve SSH connection parameters for servers.
  """

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
