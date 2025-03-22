defmodule ArchiDepWeb.Helpers.DateFormatHelpers do
  @moduledoc """
  Helper functions to format dates in the UI.
  """

  @doc """
  Formats the specified date time with the default format.

  ## Examples

      iex> LairWeb.Helpers.DateFormatHelpers.format_date_time(DateTime.new!(~D[2016-05-24], ~T[13:26:08.003], "Etc/UTC"))
      "Tue, May 24 2016 at 13:26:08"
  """
  @spec format_date_time(DateTime.t()) :: String.t()
  def format_date_time(date_time),
    do: Calendar.strftime(date_time, "%a, %B %d %Y at %H:%M:%S")
end
