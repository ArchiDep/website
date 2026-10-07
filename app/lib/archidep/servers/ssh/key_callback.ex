defmodule ArchiDep.Servers.SSH.KeyCallback do
  @moduledoc """
  Key callback module for the Erlang `:ssh` client (its `key_cb` option), which
  verifies a server's host key with a function provided when connecting.

  The `silently_accept_hosts` option of `:ssh` can also verify a host key with a
  function, but that function is only given the key's fingerprint. This module
  is given the key itself, so the verification function also receives the name
  of the key's algorithm, e.g. `ED25519`, which can be shown to a user whose
  server presented an unexpected key.

  Pass it to `:ssh.connect/3` as:

      key_cb: {ArchiDep.Servers.SSH.KeyCallback, verify_host_key: verify_host_key}

  where `verify_host_key` is a function taking the SHA-256 fingerprint of the
  key, formatted like `ssh-keygen -l` does (e.g. `SHA256:<base64>`), and the
  name of its algorithm (see `ArchiDep.Servers.SSH.SSHHostKey.algorithm_name/1`)
  and returning whether to trust the key.

  A key that is not trusted fails the connection with an error rather than being
  submitted to `silently_accept_hosts`, so no other option can accept it. The
  user's own keys, used for authentication, are loaded from the `user_dir`
  option by `:ssh_file`, as they would be without this module. Host keys are
  never saved.
  """

  @behaviour :ssh_client_key_api

  alias ArchiDep.Servers.SSH.SSHHostKey

  @type verify_host_key_fun :: (String.t(), String.t() -> boolean())

  @impl :ssh_client_key_api
  def is_host_key(key, _host, _port, algorithm, opts) do
    verify_host_key =
      opts |> Keyword.fetch!(:key_cb_private) |> Keyword.fetch!(:verify_host_key)

    fingerprint = :sha256 |> :ssh.hostkey_fingerprint(key) |> to_string()
    algorithm_name = algorithm |> Atom.to_string() |> SSHHostKey.algorithm_name()

    case verify_host_key.(fingerprint, algorithm_name) do
      true -> true
      false -> {:error, :untrusted_host_key}
    end
  end

  @impl :ssh_client_key_api
  def add_host_key(_host, _port, _key, _opts), do: {:error, :host_keys_are_not_saved}

  @impl :ssh_client_key_api
  def user_key(algorithm, opts), do: :ssh_file.user_key(algorithm, opts)
end
