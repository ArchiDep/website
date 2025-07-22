defmodule ArchiDep.Support.DateTestHelpers do
  @moduledoc """
  Helper functions to manipulate dates and datetimes in tests.
  """

  @one_hour_in_seconds 60 * 60
  @one_day_in_seconds 24 * @one_hour_in_seconds

  @doc """
  Returns an UTC `DateTime` representing the current date and time.

  ## Examples

      iex> import ArchiDep.Support.DateTestHelpers
      iex> assert_in_delta DateTime.diff(utc_now(), DateTime.utc_now(), :millisecond), 0, 10
  """
  @spec utc_now() :: DateTime.t()
  defdelegate utc_now(), to: DateTime

  @doc """
  Returns an UTC `DateTime` representing the specified number of days ago.

  ## Examples

      iex> import ArchiDep.Support.DateTestHelpers
      iex> assert_in_delta DateTime.diff(days_ago(2), DateTime.utc_now(), :millisecond), -172_800_000, 100
  """
  @spec days_ago(pos_integer) :: DateTime.t()
  def days_ago(n) when is_integer(n) and n >= 1,
    do: DateTime.add(DateTime.utc_now(), -n * @one_day_in_seconds, :second)

  @doc """
  Returns an UTC `DateTime` representing the specified number of hours ago.

  ## Examples

      iex> import ArchiDep.Support.DateTestHelpers
      iex> assert_in_delta DateTime.diff(hours_ago(2), DateTime.utc_now(), :millisecond), -7_200_000, 100
  """
  @spec hours_ago(pos_integer) :: DateTime.t()
  def hours_ago(n) when is_integer(n) and n >= 1,
    do: DateTime.add(DateTime.utc_now(), -n * @one_hour_in_seconds, :second)
end
