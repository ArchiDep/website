defmodule ArchiDep.Support.MixTaskTestHelpers do
  @moduledoc """
  Helper functions to drive Mix tasks and read what they said.

  `shell_output/0` answers with every line a task wrote, in order, so that a
  test can compare it against the whole of what a person running the task would
  see.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @typedoc """
  A line a task wrote, and which of `Mix.shell()`'s two streams it went to.
  """
  @type line :: {:info | :error, String.t()}

  @doc """
  Send what the task writes to the test process instead of the terminal, for the
  duration of one test.

  Meant to be used as an `ExUnit` `setup` callback. `Mix.shell/1` is global to
  the VM, so a test module using this must be `async: false`.
  """
  @spec capture_mix_shell(term()) :: :ok
  def capture_mix_shell(_context \\ nil) do
    previous = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(previous) end)
  end

  @doc """
  Replace the `course_site` configuration the tasks read their defaults from,
  for the duration of one test.

  It is replaced whole rather than merged into, so that a test naming one key
  states that the others are not there. Application environment is global to the
  VM, so a test module using this must be `async: false`.
  """
  @spec put_course_site_config(keyword()) :: :ok
  def put_course_site_config(config) do
    previous = Application.get_env(:archidep, :course_site, [])
    Application.put_env(:archidep, :course_site, config)
    on_exit(fn -> Application.put_env(:archidep, :course_site, previous) end)
  end

  @doc """
  Every line the task has written so far, in the order it wrote them.

  Consumes the messages, so a second call answers only what was written since
  the first.
  """
  @spec shell_output() :: [line()]
  def shell_output, do: collect([])

  defp collect(lines) do
    receive do
      {:mix_shell, level, [message]} when level in [:info, :error] ->
        collect([{level, message} | lines])
    after
      0 -> Enum.reverse(lines)
    end
  end
end
