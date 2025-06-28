defmodule ArchiDep.Helpers.PipeHelpers do
  @moduledoc """
  Helpers to work with the pipe operator.
  """

  @doc """
  Turns a value that may be nil or false into an OK or an error tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> truthy_or(42, :oops)
      {:ok, 42}
      iex> truthy_or(nil, :oops)
      {:error, :oops}
      iex> truthy_or(false, :oops)
      {:error, :oops}
  """
  @spec truthy_or(term, term) :: {:ok, term} | {:error, term}
  def truthy_or(nil, error), do: {:error, error}
  def truthy_or(false, error), do: {:error, error}
  def truthy_or(value, _error), do: {:ok, value}

  @doc """
  Maps a value through a function but only if it is truthy (i.e. not nil or false).

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> truthy_then(64, &:math.sqrt/1)
      8.0
      iex> truthy_then(nil, &:math.sqrt/1)
      nil
      iex> truthy_then(false, &:math.sqrt/1)
      false
  """
  @spec truthy_then(term, (term -> term)) :: term
  def truthy_then(nil, fun) when is_function(fun, 1), do: nil
  def truthy_then(false, fun) when is_function(fun, 1), do: false
  def truthy_then(value, fun) when is_function(fun, 1), do: fun.(value)

  @doc """
  Wraps a value in an OK tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok(42)
      {:ok, 42}
      iex> ok(nil)
      {:ok, nil}
  """
  @spec ok(term) :: {:ok, term}
  def ok(value), do: pair(value, :ok)

  @doc """
  Wraps a value in an OK tuple with an additional value.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok(42, foo: :bar)
      {:ok, 42, foo: :bar}
      iex> ok(nil, :foo)
      {:ok, nil, :foo}
  """
  @spec ok(term, term) :: {:ok, term, term}
  def ok(value, extra), do: {:ok, value, extra}

  @doc """
  Wraps a value in an error tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> error(42)
      {:error, 42}
      iex> error(:foo)
      {:error, :foo}
  """
  @spec error(term) :: {:error, term}
  def error(value), do: pair(value, :error)

  @doc """
  Wraps a value in a `GenServer` init OK tuple with a `:continue`.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok_continue(42, foo: :bar)
      {:ok, 42, {:continue, foo: :bar}}
      iex> ok_continue(nil, :foo)
      {:ok, nil, {:continue, :foo}}
  """
  @spec ok_continue(term, term) :: {:ok, term, term}
  def ok_continue(value, continue_arg), do: {:ok, value, {:continue, continue_arg}}

  @doc """
  Wraps a value into a `GenServer` no-reply tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> noreply(42)
      {:noreply, 42}
  """
  @spec noreply(term) :: {:noreply, term}
  def noreply(value), do: pair(value, :noreply)

  @doc """
  Wraps a value into a `GenServer` no-reply 3-element tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> noreply(42, {:continue, :foo})
      {:noreply, 42, {:continue, :foo}}
  """
  @spec noreply(term, opts) :: {:noreply, term, opts}
        when opts: timeout() | :hibernate | {:continue, term}
  def noreply(value, opts), do: {:noreply, value, opts}

  @doc """
  Wraps a value into a `GenServer` reply tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> reply(:ok, %{foo: :bar})
      {:reply, :ok, %{foo: :bar}}
  """
  @spec reply(term, term) :: {:reply, term, term}
  def reply(reply, state), do: {:reply, reply, state}

  @doc """
  Wraps a value into a `GenServer` reply tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> reply_with(%{foo: :bar}, :ok)
      {:reply, :ok, %{foo: :bar}}
  """
  @spec reply_with(term, term) :: {:reply, term, term}
  def reply_with(state, reply), do: {:reply, reply, state}

  @doc """
  Turns a value that may be nil or false into the :ok atom or an error tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok_atom(42, :oops)
      :ok
      iex> ok_atom({:ok, 42}, :oops)
      :ok
      iex> ok_atom(nil, :oops)
      {:error, :oops}
      iex> ok_atom(false, :oops)
      {:error, :oops}
  """
  @spec ok_atom(term, term) :: :ok | {:error, term}
  def ok_atom(nil, error), do: {:error, error}
  def ok_atom(false, error), do: {:error, error}
  def ok_atom(_value, _error), do: :ok

  @doc """
  Transforms the value in an OK/error tuple only if it is an OK tuple, returning
  an error tuple as is.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok_map({:ok, 64}, &:math.sqrt/1)
      {:ok, 8.0}
      iex> ok_map({:error, :oops}, &:math.sqrt/1)
      {:error, :oops}
  """
  @spec ok_map({:ok, term} | {:error, term}, (term -> term)) :: {:ok, term} | {:error, term}
  def ok_map({:ok, value}, func), do: {:ok, func.(value)}
  def ok_map({:error, error}, _func), do: {:error, error}

  @doc """
  Call a function with the value in an OK tuple, returning the tuple.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> {:ok, agent} = Agent.start_link(fn -> 24 end)
      iex> ok_tap({:ok, 42}, fn n -> Agent.update(agent, fn cur -> cur + n end) end)
      {:ok, 42}
      iex> Agent.get(agent, fn state -> state end)
      66
      iex> ok_tap({:error, :oops}, fn n -> Agent.update(agent, fn cur -> cur + n end) end)
      {:error, :oops}
      iex> Agent.get(agent, fn state -> state end)
      66
  """
  @spec ok_tap({:ok, term} | {:error, term}, (term -> term)) ::
          {:ok, term} | {:error, term}

  def ok_tap({:ok, value}, func) when is_function(func, 1),
    do:
      value
      |> tap(func)
      |> ok()

  def ok_tap({:error, error}, func) when is_function(func, 1), do: {:error, error}

  @doc """
  Chain together functions that produce OK/error tuples.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> ok_then({:ok, 64}, fn n -> {:ok, n * 2} end)
      {:ok, 128}
      iex> ok_then({:ok, 64}, fn _n -> {:error, :oops} end)
      {:error, :oops}
      iex> ok_then({:error, :already}, fn value -> {:ok, value} end)
      {:error, :already}
  """
  @spec ok_then({:ok, term} | {:error, term}, (term -> {:ok, term} | {:error, term})) ::
          {:ok, term} | {:error, term}

  def ok_then({:ok, value}, func) when is_function(func, 1) do
    case func.(value) do
      {:ok, new_value} -> {:ok, new_value}
      {:error, error} -> {:error, error}
    end
  end

  def ok_then({:error, error}, func) when is_function(func, 1) do
    {:error, error}
  end

  @doc """
  Transforms the value in an OK/error tuple only if it is an error tuple,
  returning an OK tuple as is.

  ## Examples

      iex> import ArchiDep.Helpers.PipeHelpers
      iex> error_map({:error, 64}, &:math.sqrt/1)
      {:error, 8.0}
      iex> error_map({:ok, :good}, &:math.sqrt/1)
      {:ok, :good}
  """
  @spec error_map({:ok, term} | {:error, term}, (term -> term)) :: {:ok, term} | {:error, term}
  def error_map({:ok, value}, _func), do: {:ok, value}
  def error_map({:error, error}, func), do: {:error, func.(error)}

  @doc """
  Turns a value into a two-element tuple with a key.

  ## Examples

      iex> ArchiDep.Helpers.PipeHelpers.pair(42, :ok)
      {:ok, 42}

      iex> ArchiDep.Helpers.PipeHelpers.pair("oops", :error)
      {:error, "oops"}
  """
  @spec pair(term, term) :: {term, term}
  def pair(value, key), do: {key, value}

  @doc """
  Extracts the value of an ok tuple.

  ## Examples

      iex> ArchiDep.Helpers.PipeHelpers.unpair_ok({:ok, 42})
      42

      iex> ArchiDep.Helpers.PipeHelpers.unpair_ok({:error, :oops})
      ** (ArgumentError) {:error, :oops} is not an ok tuple

      iex> ArchiDep.Helpers.PipeHelpers.unpair_ok(:foo)
      ** (ArgumentError) :foo is not an ok tuple
  """
  @spec unpair_ok({:ok, term}) :: term

  def unpair_ok({:ok, value}), do: value

  def unpair_ok(value),
    do: raise(ArgumentError, "#{inspect(value)} is not an ok tuple")
end
