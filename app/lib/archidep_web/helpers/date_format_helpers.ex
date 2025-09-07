defmodule ArchiDepWeb.Helpers.DateFormatHelpers do
  @moduledoc """
  Helper functions to format date and times in the UI.
  """

  use Gettext, backend: ArchiDepWeb.Gettext

  @seconds_in_one_minute 60
  @seconds_in_one_hour 3600
  @seconds_in_one_day 86_400

  @doc """
  Formats the specified date with the default format.

  ## Examples

      iex> ArchiDepWeb.Helpers.DateFormatHelpers.format_date(~D[2016-05-24])
      "Tue, May 24, 2016"
  """
  @spec format_date(Date.t()) :: String.t()
  def format_date(date), do: Calendar.strftime(date, "%a, %B %d, %Y")

  @doc """
  Formats the time part of the specified date and time with the default format.

  ## Examples

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> format_time(DateTime.new!(~D[2016-05-24], ~T[13:26:08.003], "Etc/UTC"))
      "13:26:08"
  """
  @spec format_time(DateTime.t()) :: String.t()
  def format_time(date_time), do: Calendar.strftime(date_time, "%H:%M:%S")

  @doc """
  Formats the specified date time with the default format.

  ## Examples

      iex> ArchiDepWeb.Helpers.DateFormatHelpers.format_date_time(DateTime.new!(~D[2016-05-24], ~T[13:26:08.003], "Etc/UTC"))
      "Tue, May 24, 2016 at 13:26:08"
  """
  @spec format_date_time(DateTime.t()) :: String.t()
  def format_date_time(date_time),
    do: Calendar.strftime(date_time, "%a, %B %d, %Y at %H:%M:%S")

  @doc """
  Formats the specified date time as a human-readable "time ago" string.
  The duration is computed from the difference between now and the date time.

  ## Examples

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_time_ago(DateTime.add(now, -42, :second), now)
      "42 seconds ago"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> a_little_under_two_minutes_ago = DateTime.add(now, -2 * 60 - 15, :second)
      iex> format_time_ago(a_little_under_two_minutes_ago, now)
      "2 minutes ago"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> about_three_hours_ago = DateTime.add(now, -3 * 60 * 60 - 5 * 60, :second)
      iex> format_time_ago(about_three_hours_ago, now)
      "3 hours ago"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> about_five_days_ago = -5 * 24 * 60 * 60 - 3 * 60 * 60
      iex> format_time_ago(DateTime.add(now, about_five_days_ago, :second), now)
      "5 days ago"
  """
  @spec format_time_ago(DateTime.t(), DateTime.t()) :: String.t()
  def format_time_ago(date_time, now), do: format_duration_common(date_time, now, :ago)

  @doc """
  Formats the specified date time as a human-readable duration. The duration
  is computed from the difference between now and the date time.

  ## Examples

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> two_days_and_a_half = DateTime.add(now, trunc(2.51 * 24 * 60 * 60), :second)
      iex> format_duration(two_days_and_a_half, now)
      "2 days"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_duration(DateTime.add(now, 365 * 24 * 60 * 60 + 30 * 60, :second), now)
      "365 days"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_duration(DateTime.add(now, 14 * 60 * 60 + 15 * 60 + 42, :second), now)
      "14 hours"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_duration(DateTime.add(now, 14 * 60 * 60 + 42, :second), now)
      "14 hours"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_duration(DateTime.add(now, 15 * 60 + 42, :second), now)
      "15 minutes"

      iex> import ArchiDepWeb.Helpers.DateFormatHelpers
      iex> now = DateTime.utc_now()
      iex> format_duration(DateTime.add(now, 14, :second), now)
      "14 seconds"
  """
  @spec format_duration(DateTime.t(), DateTime.t()) :: String.t()
  def format_duration(date_time, now), do: format_duration_common(now, date_time, :elapsed)

  defp format_duration_common(date_time, now, type) when type in [:ago, :elapsed] do
    seconds = now |> DateTime.diff(date_time, :second) |> max(0)

    cond do
      seconds < @seconds_in_one_minute ->
        translate_duration(seconds, :second, type)

      seconds < @seconds_in_one_hour ->
        translate_duration(div(seconds, @seconds_in_one_minute), :minute, type)

      seconds < @seconds_in_one_day ->
        translate_duration(div(seconds, @seconds_in_one_hour), :hour, type)

      true ->
        translate_duration(div(seconds, @seconds_in_one_day), :day, type)
    end
  end

  defp translate_duration(count, :second, :ago),
    do: gettext("{count} {count, plural, =1 {second} other {seconds}} ago", count: count)

  defp translate_duration(count, :second, :elapsed),
    do: gettext("{count} {count, plural, =1 {second} other {seconds}}", count: count)

  defp translate_duration(count, :minute, :ago),
    do: gettext("{count} {count, plural, =1 {minute} other {minutes}} ago", count: count)

  defp translate_duration(count, :minute, :elapsed),
    do: gettext("{count} {count, plural, =1 {minute} other {minutes}}", count: count)

  defp translate_duration(count, :hour, :ago),
    do: gettext("{count} {count, plural, =1 {hour} other {hours}} ago", count: count)

  defp translate_duration(count, :hour, :elapsed),
    do: gettext("{count} {count, plural, =1 {hour} other {hours}}", count: count)

  defp translate_duration(count, :day, :ago),
    do: gettext("{count} {count, plural, =1 {day} other {days}} ago", count: count)

  defp translate_duration(count, :day, :elapsed),
    do: gettext("{count} {count, plural, =1 {day} other {days}}", count: count)
end
