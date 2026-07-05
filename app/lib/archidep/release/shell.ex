defmodule ArchiDep.Release.Shell do
  @moduledoc """
  Pure string helpers used by the `ArchiDep.Release` tasks: escaping command
  arguments for a shell and formatting captured command output streams.
  """

  @spec shell_escape(list(String.t())) :: String.t()
  def shell_escape(args),
    do:
      Enum.map_join(args, " ", fn s ->
        if String.match?(s, ~r/[^A-Za-z0-9_\/:=\-]/) do
          s = "'" <> String.replace(s, "'", "'\\''") <> "'"

          s
          # unduplicate single-quote at the beginning
          |> String.replace(~r/^('')+/, "")
          # remove non-escaped single-quote if there are enclosed between 2 escaped
          |> String.replace(~r/\\'''/, "\\'")
        else
          s
        end
      end)

  @spec format_stream(String.t()) :: String.t()
  def format_stream(std), do: std |> String.trim() |> format_maybe_empty_stream()

  @spec format_maybe_empty_stream(String.t()) :: String.t()
  def format_maybe_empty_stream(""), do: " (empty)"
  def format_maybe_empty_stream(stream), do: "\n#{stream}"
end
