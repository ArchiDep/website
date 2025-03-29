defmodule ArchiDepWeb.Helpers.DateFormatHelpers do
  @moduledoc """
  Helper functions to format date and times in the UI.
  """

  @doc """
  Formats the specified date with the default format.

  ## Examples

      iex> LairWeb.Helpers.DateFormatHelpers.format_date(~D[2016-05-24])
      "Tue, May 24 2016"
  """
  @spec format_date(Date.t()) :: String.t()
  def format_date(date), do: Calendar.strftime(date, "%a, %B %d, %Y")

  @doc """
  Formats the specified date time with the default format.

  ## Examples

      iex> LairWeb.Helpers.DateFormatHelpers.format_date_time(DateTime.new!(~D[2016-05-24], ~T[13:26:08.003], "Etc/UTC"))
      "Tue, May 24 2016 at 13:26:08"
  """
  @spec format_date_time(DateTime.t()) :: String.t()
  def format_date_time(date_time),
    do: Calendar.strftime(date_time, "%a, %B %d, %Y at %H:%M:%S")

  @doc """
  Formats the specified date time as a human-readable duration. The duration
  is computed from the difference between now and the date time.

  ## Examples

      iex> LairWeb.Helpers.DateFormatHelpers.format_duration(DateTime.add(DateTime.utc_now(), trunc(2.51 * 24 * 60 * 60), :second))
      "2 days, 12 hours"

      iex> LairWeb.Helpers.DateFormatHelpers.format_duration(DateTime.add(DateTime.utc_now(), trunc(365 * 24 * 60 * 60 + 30 * 60), :second))
      "365 days"

      iex> LairWeb.Helpers.DateFormatHelpers.format_duration(DateTime.add(DateTime.utc_now(), trunc(14 * 60 * 60 + 15 * 60 + 42), :second))
      "14 hours, 15 minutes"

      iex> LairWeb.Helpers.DateFormatHelpers.format_duration(DateTime.add(DateTime.utc_now(), trunc(14 * 60 * 60 + 42), :second))
      "14 hours"

      iex> LairWeb.Helpers.DateFormatHelpers.format_duration(DateTime.add(DateTime.utc_now(), trunc(15 * 60 + 42), :second))
      "15 minutes, 42 seconds"
  """
  @spec format_duration(DateTime.t()) :: String.t()
  def format_duration(date_time) do
    seconds = DateTime.utc_now() |> DateTime.diff(date_time, :second) |> abs()

    {[], seconds}
    |> determine_duration_part(:day)
    |> determine_duration_part(:hour)
    |> determine_duration_part(:minute)
    |> determine_duration_part(:second)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.drop_while(fn {_interval, n} -> n == 0 end)
    |> Enum.take(2)
    |> Enum.reverse()
    |> Enum.drop_while(fn {_interval, n} -> n == 0 end)
    |> Enum.reverse()
    |> Enum.map_join(", ", &format_duration_part/1)
  end

  defp determine_duration_part({parts, remaining_seconds}, part) do
    part_seconds = seconds_in(part)
    n = div(remaining_seconds, part_seconds)
    {[{part, n} | parts], remaining_seconds - n * part_seconds}
  end

  defp seconds_in(:day), do: 24 * 60 * 60
  defp seconds_in(:hour), do: 60 * 60
  defp seconds_in(:minute), do: 60
  defp seconds_in(:second), do: 1

  defp format_duration_part({interval, 1}), do: "1 #{Atom.to_string(interval)}"
  defp format_duration_part({interval, n}), do: "#{n} #{Atom.to_string(interval)}s"
end
