defmodule ArchiDep.Helpers.GenStageHelpers do
  @moduledoc """
  Helper functions for `GenStage` stages.

  See https://hexdocs.pm/gen_stage/GenStage.html.
  """

  @doc """
  Verifies that the provided value is a valid demand for a `GenStage` pipeline.

  ## Examples

      iex> import ArchiDep.Helpers.GenStageHelpers
      iex> is_demand(42)
      true
      iex> is_demand(1)
      true
      iex> is_demand(0)
      false
      iex> is_demand(-3)
      false
      iex> is_demand("foo")
      false
  """
  @spec is_demand(term) :: Macro.t()
  defguard is_demand(demand) when is_integer(demand) and demand > 0

  @doc """
  Transforms a list of events and new state tuple into a `GenStage` no-reply
  tuple.

  ## Examples

      iex> import ArchiDep.Helpers.GenStageHelpers
      iex> noreply({["event1", "event2"], :state})
      {:noreply, ["event1", "event2"], :state}
  """
  @spec noreply({list(event), new_state}) :: {:noreply, list(event), new_state}
        when event: term, new_state: term
  def noreply({events, state}) when is_list(events), do: {:noreply, events, state}

  @doc """
  Transforms a list of events and new state tuple into a `GenStage` reply tuple.

  ## Examples

      iex> import ArchiDep.Helpers.GenStageHelpers
      iex> reply({["event1", "event2"], :state}, :ok)
      {:reply, :ok, ["event1", "event2"], :state}
  """
  @spec reply({list(event), new_state}, reply) :: {:reply, reply, list(event), new_state}
        when event: term, new_state: term, reply: term
  def reply({events, state}, reply), do: {:reply, reply, events, state}
end
