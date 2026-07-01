defmodule ArchiDep.Servers.SSH.Client do
  @moduledoc """
  Opening of SSH connections and execution of remote commands, through an
  injectable implementation.

  Code that talks to a server over SSH should go through this module instead of
  calling the Erlang `:ssh` module or `SSHEx` directly. In production it
  delegates to `ArchiDep.Servers.SSH.Client.SystemClient`; in the test
  environment it is configured to a mock so that each test can drive the
  connection logic with controlled results without opening a real SSH
  connection. See the testing guide in `docs/testing.md`.
  """

  @behaviour ArchiDep.Servers.SSH.Client.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate connect(host, port, opts), to: @implementation
  defdelegate close(connection_ref), to: @implementation
  defdelegate run_command(connection_ref, command, opts), to: @implementation
end
