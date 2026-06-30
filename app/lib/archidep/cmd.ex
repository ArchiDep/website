defmodule ArchiDep.Cmd do
  @moduledoc """
  Execution of external commands as a stream of their output, through an
  injectable implementation.

  Code that runs an external program should obtain its output stream from this
  module instead of calling `ExCmd.stream/2` directly. In production it
  delegates to `ExCmd`; in the test environment it is configured to a mock so
  that each test can drive the parsing logic with a controlled output stream
  without spawning a real subprocess.
  """

  @behaviour ArchiDep.Cmd.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate stream(command, opts), to: @implementation
end
