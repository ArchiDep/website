defmodule ArchiDep.Servers.SSH.Client.SystemClient do
  @moduledoc """
  Default `ArchiDep.Servers.SSH.Client` implementation opening real SSH
  connections through the Erlang `:ssh` module and running commands through
  `SSHEx`.
  """

  @behaviour ArchiDep.Servers.SSH.Client.Behaviour

  @impl ArchiDep.Servers.SSH.Client.Behaviour
  def connect(host, port, opts), do: :ssh.connect(host, port, opts)

  @impl ArchiDep.Servers.SSH.Client.Behaviour
  def close(connection_ref), do: :ssh.close(connection_ref)

  @impl ArchiDep.Servers.SSH.Client.Behaviour
  def run_command(connection_ref, command, opts), do: SSHEx.run(connection_ref, command, opts)
end
