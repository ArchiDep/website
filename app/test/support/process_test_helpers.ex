defmodule ArchiDep.Support.ProcessTestHelpers do
  @moduledoc """
  Helper functions to test processes and their state.
  """

  @wait 5

  @doc """
  Wait for a process's state to fulfill the specified condition.

  ## Examples

      iex> import ArchiDep.Support.ProcessTestHelpers
      iex> {:ok, agent} = Agent.start_link fn -> [] end
      iex> :ok = wait_for_state!(agent, fn state -> state == [] end, "oops")
      iex> Task.start(fn ->
      ...>   Process.sleep(10)
      ...>   Agent.update(agent, fn data -> ["foo" | data] end)
      ...> end)
      iex> {usec, :ok} = :timer.tc(fn -> wait_for_state!(agent, fn state -> Enum.member?(state, "foo") end, "oops") end)
      iex> assert_in_delta usec, 15_000, 100_000
      iex> wait_for_state!(agent, fn state -> Enum.member?(state, "bar") end, "bar not found", 10)
      ** (RuntimeError) Process state ["foo"] never matched: bar not found
  """
  @spec wait_for_state!(
          pid,
          (term -> boolean),
          String.t(),
          pos_integer(),
          non_neg_integer()
        ) :: :ok
  def wait_for_state!(pid, predicate, error_msg, timeout \\ 100, waited \\ 0)
      when is_pid(pid) and is_function(predicate, 1) and is_binary(error_msg) and
             is_integer(timeout) and timeout > 0 and is_integer(waited) and waited >= 0 do
    state = :sys.get_state(pid)

    cond do
      predicate.(state) ->
        :ok

      waited + @wait > timeout ->
        raise "Process state #{inspect(state)} never matched: #{error_msg}"

      true ->
        Process.sleep(@wait)
        wait_for_state!(pid, predicate, error_msg, timeout, waited + @wait)
    end
  end

  @doc """
  Wait for a condition to be fulfilled.

  ## Examples

      iex> import ArchiDep.Support.ProcessTestHelpers
      iex> {:ok, agent} = Agent.start_link fn -> [] end
      iex> :ok = wait_for!(fn -> Agent.get(agent, fn state -> state end) == [] end, "oops")
      iex> Task.start(fn ->
      ...>   Process.sleep(10)
      ...>   Agent.update(agent, fn data -> ["foo" | data] end)
      ...> end)
      iex> {usec, :ok} = :timer.tc(fn -> wait_for!(fn -> Agent.get(agent, fn state -> Enum.member?(state, "foo") end) end, "oops") end)
      iex> assert_in_delta usec, 15_000, 100_000
      iex> wait_for!(fn -> Agent.get(agent, fn state -> Enum.member?(state, "bar") end) end, "bar not found", 10)
      ** (RuntimeError) Condition never fulfilled: bar not found
  """
  @spec wait_for!(
          (-> boolean),
          String.t(),
          pos_integer(),
          non_neg_integer()
        ) :: :ok
  def wait_for!(condition, error_msg, timeout \\ 100, waited \\ 0)
      when is_function(condition, 0) and is_binary(error_msg) and
             is_integer(timeout) and timeout > 0 and is_integer(waited) and waited >= 0 do
    cond do
      condition.() ->
        :ok

      waited + @wait > timeout ->
        raise "Condition never fulfilled: #{error_msg}"

      true ->
        Process.sleep(@wait)
        wait_for!(condition, error_msg, timeout, waited + @wait)
    end
  end
end
